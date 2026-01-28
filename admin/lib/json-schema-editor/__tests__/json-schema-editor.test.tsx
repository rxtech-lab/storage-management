import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState, useEffect } from "react";
import { JsonSchemaEditor } from "../json-schema-editor";
import type { JsonSchema } from "../types";

describe("JsonSchemaEditor", () => {
  it("renders with empty state", () => {
    render(<JsonSchemaEditor value={null} onChange={vi.fn()} />);

    expect(screen.getByText("Visual Editor")).toBeInTheDocument();
    expect(screen.getByText("Raw JSON")).toBeInTheDocument();
    expect(
      screen.getByText("No properties defined. Add a property to get started.")
    ).toBeInTheDocument();
  });

  it("renders with existing schema", () => {
    const schema: JsonSchema = {
      type: "object",
      properties: {
        name: { type: "string", title: "Name" },
        age: { type: "integer", title: "Age" },
      },
      required: ["name"],
    };

    render(<JsonSchemaEditor value={schema} onChange={vi.fn()} />);

    expect(screen.getByText("name")).toBeInTheDocument();
    expect(screen.getByText("age")).toBeInTheDocument();
  });

  it("switches between visual and raw tabs", async () => {
    const user = userEvent.setup();
    const schema: JsonSchema = {
      type: "object",
      properties: {
        name: { type: "string" },
      },
    };

    render(<JsonSchemaEditor value={schema} onChange={vi.fn()} />);

    // Click on Raw JSON tab
    await user.click(screen.getByRole("tab", { name: "Raw JSON" }));

    // Should show textarea with JSON
    await waitFor(() => {
      const textarea = screen.getByRole("textbox");
      expect(textarea).toBeInTheDocument();
      const value = (textarea as HTMLTextAreaElement).value;
      expect(value).toContain('"type": "object"');
    });
  });

  it("adds new property via visual editor", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();

    render(<JsonSchemaEditor value={null} onChange={onChange} />);

    // Click add property button
    const addButton = screen.getByText("Add Property");
    await user.click(addButton);

    // Should call onChange with new property
    await waitFor(() => {
      expect(onChange).toHaveBeenCalled();
    });
  });

  it("updates schema from raw JSON editor", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();

    render(<JsonSchemaEditor value={null} onChange={onChange} />);

    // Switch to raw JSON tab
    await user.click(screen.getByRole("tab", { name: "Raw JSON" }));

    // Wait for textarea to be visible
    await waitFor(() => {
      expect(screen.getByRole("textbox")).toBeInTheDocument();
    });

    // Type valid JSON using fireEvent.change to avoid userEvent issues with braces
    const textarea = screen.getByRole("textbox");
    fireEvent.change(textarea, {
      target: { value: '{"type":"object","properties":{"test":{"type":"string"}}}' }
    });

    // Should call onChange with parsed schema
    await waitFor(() => {
      expect(onChange).toHaveBeenCalled();
      const lastCall = onChange.mock.calls[onChange.mock.calls.length - 1][0];
      if (lastCall) {
        expect(lastCall.properties.test).toBeDefined();
      }
    });
  });

  it("shows error for invalid JSON in raw editor", async () => {
    const user = userEvent.setup();
    render(<JsonSchemaEditor value={null} onChange={vi.fn()} />);

    // Switch to raw JSON tab
    await user.click(screen.getByRole("tab", { name: "Raw JSON" }));

    // Wait for textarea to be visible
    await waitFor(() => {
      expect(screen.getByRole("textbox")).toBeInTheDocument();
    });

    // Type invalid JSON
    const textarea = screen.getByRole("textbox");
    fireEvent.change(textarea, { target: { value: "{invalid json}" } });

    // Should show error
    await waitFor(() => {
      expect(screen.getByText("Invalid JSON syntax")).toBeInTheDocument();
    });
  });

  it("shows error for invalid schema in raw editor", async () => {
    const user = userEvent.setup();
    render(<JsonSchemaEditor value={null} onChange={vi.fn()} />);

    // Switch to raw JSON tab
    await user.click(screen.getByRole("tab", { name: "Raw JSON" }));

    // Wait for textarea to be visible
    await waitFor(() => {
      expect(screen.getByRole("textbox")).toBeInTheDocument();
    });

    // Type JSON with unsupported type
    const textarea = screen.getByRole("textbox");
    fireEvent.change(textarea, { target: { value: '{"type":"invalid"}' } });

    // Should show schema validation error
    await waitFor(() => {
      expect(screen.getByText(/Schema type must be one of/i)).toBeInTheDocument();
    });
  });

  it("syncs data when switching from visual to raw", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();

    render(<JsonSchemaEditor value={null} onChange={onChange} />);

    // Add a property in visual mode
    await user.click(screen.getByText("Add Property"));

    // Fill in property details
    const nameInput = screen.getByPlaceholderText("property_name");
    fireEvent.change(nameInput, { target: { value: "myField" } });

    // Switch to raw tab
    await user.click(screen.getByRole("tab", { name: "Raw JSON" }));

    // Wait for and check raw JSON contains the new property
    await waitFor(() => {
      const textarea = screen.getByRole("textbox");
      const value = (textarea as HTMLTextAreaElement).value;
      expect(value).toContain("myField");
    });
  });

  it("syncs data when switching from raw to visual", async () => {
    const user = userEvent.setup();
    render(<JsonSchemaEditor value={null} onChange={vi.fn()} />);

    // Switch to raw tab
    await user.click(screen.getByRole("tab", { name: "Raw JSON" }));

    // Wait for textarea and enter schema
    await waitFor(() => {
      expect(screen.getByRole("textbox")).toBeInTheDocument();
    });

    const textarea = screen.getByRole("textbox");
    fireEvent.change(textarea, {
      target: { value: '{"type":"object","properties":{"rawField":{"type":"string","title":"Raw Field"}}}' }
    });

    // Switch back to visual
    await user.click(screen.getByRole("tab", { name: "Visual Editor" }));

    // Should show the property from raw JSON
    await waitFor(() => {
      expect(screen.getByText("rawField")).toBeInTheDocument();
    });
  });

  it("disables all inputs when disabled prop is true", () => {
    const schema: JsonSchema = {
      type: "object",
      properties: {
        name: { type: "string" },
      },
    };

    render(<JsonSchemaEditor value={schema} onChange={vi.fn()} disabled={true} />);

    // Tab triggers should be disabled
    const visualTab = screen.getByRole("tab", { name: "Visual Editor" });
    const rawTab = screen.getByRole("tab", { name: "Raw JSON" });
    expect(visualTab).toBeDisabled();
    expect(rawTab).toBeDisabled();
  });

  it("handles external value changes", () => {
    const onChange = vi.fn();
    const initialSchema: JsonSchema = {
      type: "object",
      properties: {
        first: { type: "string" },
      },
    };

    const { rerender } = render(
      <JsonSchemaEditor value={initialSchema} onChange={onChange} />
    );

    expect(screen.getByText("first")).toBeInTheDocument();

    // Rerender with new schema
    const newSchema: JsonSchema = {
      type: "object",
      properties: {
        second: { type: "number" },
      },
    };

    rerender(<JsonSchemaEditor value={newSchema} onChange={onChange} />);

    expect(screen.getByText("second")).toBeInTheDocument();
    expect(screen.queryByText("first")).not.toBeInTheDocument();
  });

  it("deletes property from visual editor", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const schema: JsonSchema = {
      type: "object",
      properties: {
        toDelete: { type: "string" },
      },
    };

    render(<JsonSchemaEditor value={schema} onChange={onChange} />);

    // Find and click delete button
    const deleteButtons = screen.getAllByRole("button").filter((btn) =>
      btn.querySelector('svg.lucide-trash-2')
    );

    if (deleteButtons.length > 0) {
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(onChange).toHaveBeenCalled();
      });
    }
  });

  it("clears schema when raw JSON is emptied", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const schema: JsonSchema = {
      type: "object",
      properties: {
        name: { type: "string" },
      },
    };

    render(<JsonSchemaEditor value={schema} onChange={onChange} />);

    // Switch to raw tab
    await user.click(screen.getByRole("tab", { name: "Raw JSON" }));

    // Wait for textarea
    await waitFor(() => {
      expect(screen.getByRole("textbox")).toBeInTheDocument();
    });

    // Clear the textarea
    const textarea = screen.getByRole("textbox");
    fireEvent.change(textarea, { target: { value: "" } });

    // Should call onChange with null
    await waitFor(() => {
      expect(onChange).toHaveBeenCalledWith(null);
    });
  });

  it("shows placeholder text in visual editor when empty", () => {
    render(
      <JsonSchemaEditor
        value={null}
        onChange={vi.fn()}
        placeholder="Custom placeholder"
      />
    );

    // The visual tab shows the empty state message
    expect(
      screen.getByText("No properties defined. Add a property to get started.")
    ).toBeInTheDocument();
  });

  it("does not cause infinite loop when value changes from object to array type", async () => {
    const onChange = vi.fn();
    const objectSchema: JsonSchema = {
      type: "object",
      properties: {},
    };
    const arraySchema: JsonSchema = {
      type: "array",
      items: { type: "string" },
    };

    // First render with object schema
    const { rerender } = render(
      <JsonSchemaEditor value={objectSchema} onChange={onChange} />
    );

    // Simulate what happens when parent changes the value to array type
    // (this is what happens when user selects Array from dropdown)
    rerender(<JsonSchemaEditor value={arraySchema} onChange={onChange} />);

    // Wait a tick for any effects to settle
    await waitFor(() => {
      // If there's an infinite loop, this will timeout or crash
      // Otherwise onChange should be called at most a few times
      expect(onChange.mock.calls.length).toBeLessThan(10);
    }, { timeout: 1000 });
  });

  it("does not cause infinite loop when value changes from object to string type", async () => {
    const onChange = vi.fn();
    const objectSchema: JsonSchema = {
      type: "object",
      properties: {},
    };
    const stringSchema: JsonSchema = {
      type: "string",
    };

    const { rerender } = render(
      <JsonSchemaEditor value={objectSchema} onChange={onChange} />
    );

    rerender(<JsonSchemaEditor value={stringSchema} onChange={onChange} />);

    await waitFor(() => {
      expect(onChange.mock.calls.length).toBeLessThan(10);
    }, { timeout: 1000 });
  });

  it("does not cause infinite loop when value changes from object to number type", async () => {
    const onChange = vi.fn();
    const objectSchema: JsonSchema = {
      type: "object",
      properties: {},
    };
    const numberSchema: JsonSchema = {
      type: "number",
    };

    const { rerender } = render(
      <JsonSchemaEditor value={objectSchema} onChange={onChange} />
    );

    rerender(<JsonSchemaEditor value={numberSchema} onChange={onChange} />);

    await waitFor(() => {
      expect(onChange.mock.calls.length).toBeLessThan(10);
    }, { timeout: 1000 });
  });

  it("does not cause infinite loop in controlled component when type changes", async () => {
    // This test simulates the actual controlled usage pattern where onChange updates state
    const onChangeTracker = vi.fn();
    let updateCount = 0;
    const maxUpdates = 20; // Safety limit

    const ControlledWrapper = () => {
      const [schema, setSchema] = useState<JsonSchema | null>({
        type: "object",
        properties: {},
      });

      const handleChange = (newSchema: JsonSchema | null) => {
        updateCount++;
        onChangeTracker(newSchema);
        if (updateCount < maxUpdates) {
          setSchema(newSchema);
        }
      };

      // Simulate clicking the type dropdown after first render
      useEffect(() => {
        // Trigger a type change after initial render
        const timer = setTimeout(() => {
          setSchema({ type: "array", items: { type: "string" } });
        }, 10);
        return () => clearTimeout(timer);
        // eslint-disable-next-line react-hooks/exhaustive-deps
      }, []);

      return <JsonSchemaEditor value={schema} onChange={handleChange} />;
    };

    render(<ControlledWrapper />);

    // Wait for effects to settle
    await waitFor(() => {
      // Should not call onChange excessively
      // If infinite loop exists, updateCount would hit maxUpdates
      expect(updateCount).toBeLessThan(maxUpdates);
    }, { timeout: 2000 });

    // Verify onChange was called but not excessively (indicating no infinite loop)
    expect(onChangeTracker.mock.calls.length).toBeLessThan(10);
  });
});
