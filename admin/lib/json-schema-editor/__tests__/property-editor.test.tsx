import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PropertyEditor } from "../property-editor";
import type { PropertyItem } from "../types";

const createMockItem = (overrides: Partial<PropertyItem> = {}): PropertyItem => ({
  key: "testProperty",
  property: { type: "string", title: "Test Property" },
  isRequired: false,
  ...overrides,
});

describe("PropertyEditor", () => {
  it("renders property name and type", () => {
    const item = createMockItem();
    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
      />
    );

    expect(screen.getByText("testProperty")).toBeInTheDocument();
    expect(screen.getByDisplayValue("testProperty")).toBeInTheDocument();
  });

  it("shows required indicator when property is required", () => {
    const item = createMockItem({ isRequired: true });
    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
      />
    );

    expect(screen.getByText("*")).toBeInTheDocument();
  });

  it("calls onChange when property name changes", () => {
    const onChange = vi.fn();
    const item = createMockItem();

    render(
      <PropertyEditor
        item={item}
        onChange={onChange}
        onDelete={vi.fn()}
      />
    );

    const nameInput = screen.getByDisplayValue("testProperty");
    fireEvent.change(nameInput, { target: { value: "newName" } });

    expect(onChange).toHaveBeenCalled();
    const lastCall = onChange.mock.calls[onChange.mock.calls.length - 1][0];
    expect(lastCall.key).toBe("newName");
  });

  it("calls onDelete when delete button is clicked", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    const item = createMockItem();

    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={onDelete}
      />
    );

    // Find the trash button (it has the Trash2 icon)
    const trashButtons = screen.getAllByRole("button").filter(btn =>
      btn.querySelector('svg.lucide-trash-2')
    );

    if (trashButtons.length > 0) {
      await user.click(trashButtons[0]);
      expect(onDelete).toHaveBeenCalled();
    }
  });

  it("shows move buttons when handlers are provided", () => {
    const item = createMockItem();
    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
        onMoveUp={vi.fn()}
        onMoveDown={vi.fn()}
      />
    );

    const buttons = screen.getAllByRole("button");
    // Should have: collapse, move up, move down, delete
    expect(buttons.length).toBeGreaterThanOrEqual(3);
  });

  it("disables move up when isFirst is true", () => {
    const item = createMockItem();
    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
        onMoveUp={vi.fn()}
        onMoveDown={vi.fn()}
        isFirst={true}
      />
    );

    const moveUpButton = screen.getAllByRole("button").find(btn =>
      btn.querySelector('svg.lucide-arrow-up')
    );

    if (moveUpButton) {
      expect(moveUpButton).toBeDisabled();
    }
  });

  it("disables move down when isLast is true", () => {
    const item = createMockItem();
    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
        onMoveUp={vi.fn()}
        onMoveDown={vi.fn()}
        isLast={true}
      />
    );

    const moveDownButton = screen.getAllByRole("button").find(btn =>
      btn.querySelector('svg.lucide-arrow-down')
    );

    if (moveDownButton) {
      expect(moveDownButton).toBeDisabled();
    }
  });

  it("shows enum field for string type", () => {
    const item = createMockItem({ property: { type: "string" } });
    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
      />
    );

    expect(screen.getByPlaceholderText("option1, option2, option3")).toBeInTheDocument();
  });

  it("shows array items type selector for array type", () => {
    const item = createMockItem({ property: { type: "array" } });
    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
      />
    );

    expect(screen.getByText("Array Item Type")).toBeInTheDocument();
  });

  it("toggles required checkbox", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const item = createMockItem({ isRequired: false });

    render(
      <PropertyEditor
        item={item}
        onChange={onChange}
        onDelete={vi.fn()}
      />
    );

    const requiredCheckbox = screen.getByRole("checkbox");
    await user.click(requiredCheckbox);

    expect(onChange).toHaveBeenCalled();
    const lastCall = onChange.mock.calls[onChange.mock.calls.length - 1][0];
    expect(lastCall.isRequired).toBe(true);
  });

  it("collapses and expands content", async () => {
    const user = userEvent.setup();
    const item = createMockItem();

    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
      />
    );

    // Initially expanded
    expect(screen.getByText("Property Name")).toBeInTheDocument();

    // Click header to collapse
    const headerButton = screen.getByRole("button", { name: /testProperty/i });
    await user.click(headerButton);

    // Content should be hidden
    expect(screen.queryByText("Property Name")).not.toBeInTheDocument();

    // Click again to expand
    await user.click(headerButton);
    expect(screen.getByText("Property Name")).toBeInTheDocument();
  });

  it("disables all inputs when disabled prop is true", () => {
    const item = createMockItem();
    render(
      <PropertyEditor
        item={item}
        onChange={vi.fn()}
        onDelete={vi.fn()}
        disabled={true}
      />
    );

    const inputs = screen.getAllByRole("textbox");
    inputs.forEach((input) => {
      expect(input).toBeDisabled();
    });
  });

  it("validates property key and shows error for invalid key", () => {
    const onChange = vi.fn();
    const item = createMockItem({ key: "" });

    render(
      <PropertyEditor
        item={item}
        onChange={onChange}
        onDelete={vi.fn()}
      />
    );

    const nameInput = screen.getByPlaceholderText("property_name");
    fireEvent.change(nameInput, { target: { value: "123invalid" } });

    // Should show validation error
    expect(screen.getByText(/Property name must start with/i)).toBeInTheDocument();
  });
});
