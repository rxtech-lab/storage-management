import { describe, it, expect, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { EntityCombobox } from "../entity-combobox";

// Mock EntitySheet to avoid complexity
vi.mock("../entity-sheet", () => ({
  EntitySheet: () => <button>+</button>,
}));

type TestItem = { id: number; name: string };

const defaultProps = {
  value: null as number | null,
  onSelect: vi.fn(),
  items: [] as TestItem[],
  isSearching: false,
  hasSearchQuery: false,
  onSearch: vi.fn(),
  getItemId: (item: TestItem) => item.id,
  getItemLabel: (item: TestItem) => item.name,
  itemRenderer: (item: TestItem) => item.name,
  label: "Test Entity",
  placeholder: "Search...",
  emptyMessage: "No results found",
};

describe("EntityCombobox", () => {
  it("renders with label and placeholder", () => {
    render(<EntityCombobox {...defaultProps} />);

    expect(screen.getByText("Test Entity")).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Search...")).toBeInTheDocument();
  });

  it("shows items from items prop", async () => {
    const items = [
      { id: 1, name: "Item One" },
      { id: 2, name: "Item Two" },
    ];

    render(<EntityCombobox {...defaultProps} items={items} />);

    const input = screen.getByPlaceholderText("Search...");
    await userEvent.click(input);

    await waitFor(() => {
      expect(screen.getByText("Item One")).toBeInTheDocument();
      expect(screen.getByText("Item Two")).toBeInTheDocument();
    });
  });

  it("shows loading spinner when isSearching is true", async () => {
    render(<EntityCombobox {...defaultProps} isSearching={true} />);

    const input = screen.getByPlaceholderText("Search...");
    await userEvent.click(input);

    await waitFor(() => {
      // Check for the loader spinner (Loader2 icon with animate-spin class)
      const spinner = document.querySelector(".animate-spin");
      expect(spinner).toBeInTheDocument();
    });
  });

  it("calls onSearch when input value changes", async () => {
    const onSearch = vi.fn();
    render(<EntityCombobox {...defaultProps} onSearch={onSearch} />);

    const input = screen.getByPlaceholderText("Search...");
    await userEvent.click(input);
    await userEvent.clear(input);
    await userEvent.type(input, "test");

    // onSearch is called with the current input value and an event object
    expect(onSearch).toHaveBeenCalled();
    // Check that one of the calls included "test"
    const calls = onSearch.mock.calls.map((call) => call[0]);
    expect(calls).toContain("test");
  });

  it("calls onSelect with item id when item is selected", async () => {
    const onSelect = vi.fn();
    const items = [{ id: 42, name: "Test Item" }];

    render(
      <EntityCombobox {...defaultProps} items={items} onSelect={onSelect} />
    );

    const input = screen.getByPlaceholderText("Search...");
    await userEvent.click(input);

    await waitFor(() => {
      expect(screen.getByText("Test Item")).toBeInTheDocument();
    });

    await userEvent.click(screen.getByText("Test Item"));

    expect(onSelect).toHaveBeenCalledWith(42);
  });

  it("calls onSelect with null when None is selected", async () => {
    const onSelect = vi.fn();
    const items = [{ id: 1, name: "Some Item" }];

    render(
      <EntityCombobox
        {...defaultProps}
        items={items}
        value={1}
        onSelect={onSelect}
        hasSearchQuery={false}
      />
    );

    const input = screen.getByPlaceholderText("Search...");
    await userEvent.click(input);

    await waitFor(() => {
      expect(screen.getByText("None")).toBeInTheDocument();
    });

    await userEvent.click(screen.getByText("None"));

    expect(onSelect).toHaveBeenCalledWith(null);
  });

  it("shows None option only when not searching", async () => {
    const items = [{ id: 1, name: "Test Item" }];

    // When not searching (hasSearchQuery=false), None should be visible
    const { rerender } = render(
      <EntityCombobox {...defaultProps} items={items} hasSearchQuery={false} />
    );

    const input = screen.getByPlaceholderText("Search...");
    await userEvent.click(input);

    await waitFor(() => {
      expect(screen.getByText("None")).toBeInTheDocument();
    });

    // When searching (hasSearchQuery=true), None should not be visible
    rerender(
      <EntityCombobox {...defaultProps} items={items} hasSearchQuery={true} />
    );

    await waitFor(() => {
      expect(screen.queryByText("None")).not.toBeInTheDocument();
    });
  });

  it("shows empty message when no results and searching", async () => {
    render(
      <EntityCombobox
        {...defaultProps}
        items={[]}
        hasSearchQuery={true}
        isSearching={false}
      />
    );

    const input = screen.getByPlaceholderText("Search...");
    await userEvent.click(input);

    await waitFor(() => {
      expect(screen.getByText("No results found")).toBeInTheDocument();
    });
  });

  it("uses custom itemRenderer for item display", async () => {
    const items = [{ id: 1, name: "Test" }];
    const customRenderer = (item: TestItem) => `Custom: ${item.name}`;

    render(
      <EntityCombobox
        {...defaultProps}
        items={items}
        itemRenderer={customRenderer}
      />
    );

    const input = screen.getByPlaceholderText("Search...");
    await userEvent.click(input);

    await waitFor(() => {
      expect(screen.getByText("Custom: Test")).toBeInTheDocument();
    });
  });

  it("uses custom selectedValueRenderer for selected label", async () => {
    const items = [{ id: 1, name: "Item" }];
    const selectedValueRenderer = (item: TestItem) => `Selected: ${item.name}`;

    render(
      <EntityCombobox
        {...defaultProps}
        items={items}
        value={1}
        selectedValueRenderer={selectedValueRenderer}
      />
    );

    // The input should show the custom rendered value
    const input = screen.getByPlaceholderText("Search...");
    expect(input).toHaveValue("Selected: Item");
  });

  it("shows EntitySheet button when entitySheetType is provided", () => {
    render(
      <EntityCombobox
        {...defaultProps}
        entitySheetType="author"
        onEntityCreated={vi.fn()}
      />
    );

    // The mocked EntitySheet renders a "+" button
    expect(screen.getByText("+")).toBeInTheDocument();
  });

  it("does not show EntitySheet button when entitySheetType is not provided", () => {
    render(<EntityCombobox {...defaultProps} />);

    expect(screen.queryByText("+")).not.toBeInTheDocument();
  });

  it("displays selected item label in input", async () => {
    const items = [{ id: 5, name: "Selected Item" }];

    render(<EntityCombobox {...defaultProps} items={items} value={5} />);

    const input = screen.getByPlaceholderText("Search...");
    expect(input).toHaveValue("Selected Item");
  });

  it("displays empty input when value is null", () => {
    render(<EntityCombobox {...defaultProps} value={null} />);

    const input = screen.getByPlaceholderText("Search...");
    expect(input).toHaveValue("");
  });

  it("uses custom noneLabel in dropdown", async () => {
    render(
      <EntityCombobox
        {...defaultProps}
        value={null}
        noneLabel="No Selection"
        hasSearchQuery={false}
      />
    );

    // Input should be empty, not showing the noneLabel
    const input = screen.getByPlaceholderText("Search...");
    expect(input).toHaveValue("");

    // But the dropdown should show the custom noneLabel
    await userEvent.click(input);

    await waitFor(() => {
      expect(screen.getByText("No Selection")).toBeInTheDocument();
    });
  });
});
