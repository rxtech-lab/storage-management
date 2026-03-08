//
//  DashboardChartsView.swift
//  RxStorage
//
//  Dashboard charts detail pane for iPad/macOS with Swift Charts
//

import Charts
import RxStorageCore
import SwiftUI

/// Dashboard charts view showing analytics in the detail column
struct DashboardChartsView: View {
    @State private var viewModel = DashboardChartsViewModel()
    @State private var showingError = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.charts == nil {
                ProgressView("Loading charts...")
            } else if let charts = viewModel.charts {
                chartsContent(charts)
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("Unable to load chart data")
                )
            }
        }
        .navigationTitle("Analytics")
        .task {
            await viewModel.loadCharts()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.error != nil) { _, hasError in
            showingError = hasError
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { viewModel.clearError() }
            Button("Retry") {
                Task { await viewModel.loadCharts() }
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Charts Content

    private func chartsContent(_ charts: DashboardCharts) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ],
                spacing: 16
            ) {
                // Items by Month (timeline) — full width
                if !charts.itemsByMonth.isEmpty {
                    chartCard(title: "Items Over Time", icon: "calendar") {
                        itemsByMonthChart(charts.itemsByMonth)
                    }
                    .gridCellColumns(2)
                }

                // Items by Location
                if !charts.itemsByLocation.isEmpty {
                    chartCard(title: "By Location", icon: "mappin.circle") {
                        horizontalBarChart(charts.itemsByLocation, palette: Self.bluePalette)
                    }
                }

                // Items by Category
                if !charts.itemsByCategory.isEmpty {
                    chartCard(title: "By Category", icon: "folder") {
                        horizontalBarChart(charts.itemsByCategory, palette: Self.greenPalette)
                    }
                }

                // Items by Tag
                if !charts.itemsByTag.isEmpty {
                    chartCard(title: "By Tag", icon: "tag") {
                        tagBarChart(charts.itemsByTag)
                    }
                }

                // Items by Author
                if !charts.itemsByAuthor.isEmpty {
                    chartCard(title: "By Author", icon: "person.circle") {
                        horizontalBarChart(charts.itemsByAuthor, palette: Self.purplePalette)
                    }
                }

                // Items by Visibility
                if !charts.itemsByVisibility.isEmpty {
                    chartCard(title: "By Visibility", icon: "eye") {
                        visibilityDonutChart(charts.itemsByVisibility)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Chart Card Wrapper

    private func chartCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
                .frame(height: 200)
        }
        .padding()
        .background {
            #if os(iOS)
                Color(.secondarySystemBackground)
            #elseif os(macOS)
                Color(nsColor: .controlBackgroundColor)
            #endif
        }
        .cornerRadius(12)
    }

    // MARK: - Items by Month (Area/Line Chart)

    private func itemsByMonthChart(_ data: [DashboardChartDataPoint]) -> some View {
        Chart(data, id: \.label) { point in
            AreaMark(
                x: .value("Month", point.label),
                y: .value("Items", point.value)
            )
            .foregroundStyle(.blue.opacity(0.2))

            LineMark(
                x: .value("Month", point.label),
                y: .value("Items", point.value)
            )
            .foregroundStyle(.blue)

            PointMark(
                x: .value("Month", point.label),
                y: .value("Items", point.value)
            )
            .foregroundStyle(.blue)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    // MARK: - Color Palettes

    private static let bluePalette: [Color] = [
        .blue, .cyan, .teal, .mint, .indigo,
    ]

    private static let greenPalette: [Color] = [
        .green, .mint, .teal, .cyan, .blue,
    ]

    private static let purplePalette: [Color] = [
        .purple, .indigo, .pink, .blue, .cyan,
    ]

    // MARK: - Horizontal Bar Chart

    private func horizontalBarChart(
        _ data: [DashboardChartDataPoint],
        palette: [Color]
    ) -> some View {
        Chart(Array(data.enumerated()), id: \.element.label) { index, point in
            BarMark(
                x: .value("Count", point.value),
                y: .value("Name", point.label)
            )
            .foregroundStyle(palette[index % palette.count].gradient)
            .annotation(position: .trailing) {
                Text("\(point.value)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tag Bar Chart (with colors)

    private func tagBarChart(_ data: [DashboardChartDataPoint]) -> some View {
        Chart(Array(data.enumerated()), id: \.element.label) { _, point in
            BarMark(
                x: .value("Count", point.value),
                y: .value("Tag", point.label)
            )
            .foregroundStyle(colorFromHex(point.color).gradient)
            .annotation(position: .trailing) {
                Text("\(point.value)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Visibility Donut Chart

    private func visibilityDonutChart(_ data: [DashboardChartDataPoint]) -> some View {
        Chart(data, id: \.label) { point in
            SectorMark(
                angle: .value("Count", point.value),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(colorFromHex(point.color))
            .annotation(position: .overlay) {
                VStack(spacing: 2) {
                    Text(point.label)
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("\(point.value)")
                        .font(.caption)
                }
                .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Helpers

    private func colorFromHex(_ hex: String?) -> Color {
        guard let hex = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")) else {
            return .blue
        }
        guard hex.count == 6, let rgb = UInt64(hex, radix: 16) else {
            return .blue
        }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
