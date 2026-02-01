"use client"

import * as React from "react"
import {
  Combobox as HeadlessCombobox,
  ComboboxInput as HeadlessComboboxInput,
  ComboboxButton,
  ComboboxOptions,
  ComboboxOption,
} from "@headlessui/react"
import { cn } from "@/lib/utils"
import { ChevronDownIcon, XIcon, CheckIcon } from "lucide-react"

// Context for sharing state between components
interface ComboboxContextValue {
  value: string
  onValueChange: (value: unknown) => void
  onInputValueChange: (value: string) => void
  inputValue: string
  setInputValue: (value: string) => void
}

const ComboboxContext = React.createContext<ComboboxContextValue | null>(null)

function useComboboxContext() {
  const context = React.useContext(ComboboxContext)
  if (!context) {
    throw new Error("Combobox components must be used within a Combobox")
  }
  return context
}

// Root component
interface ComboboxProps {
  value: string
  onValueChange: (value: unknown) => void
  onInputValueChange: (value: string) => void
  children: React.ReactNode
}

function Combobox({
  value,
  onValueChange,
  onInputValueChange,
  children,
}: ComboboxProps) {
  const [inputValue, setInputValue] = React.useState(value)

  // Sync input value with controlled value
  React.useEffect(() => {
    setInputValue(value)
  }, [value])

  const handleInputChange = (newValue: string) => {
    setInputValue(newValue)
    onInputValueChange(newValue)
  }

  return (
    <ComboboxContext.Provider
      value={{
        value,
        onValueChange,
        onInputValueChange,
        inputValue,
        setInputValue: handleInputChange,
      }}
    >
      <HeadlessCombobox
        value={value}
        onChange={onValueChange}
        onClose={() => setInputValue(value)}
      >
        <div className="relative">
          {children}
        </div>
      </HeadlessCombobox>
    </ComboboxContext.Provider>
  )
}

// Input component
interface ComboboxInputProps {
  placeholder?: string
  showClear?: boolean
  showTrigger?: boolean
  className?: string
  disabled?: boolean
}

function ComboboxInput({
  placeholder,
  showClear = false,
  showTrigger = true,
  className,
  disabled = false,
}: ComboboxInputProps) {
  const { inputValue, setInputValue, value, onValueChange } = useComboboxContext()

  return (
    <div className={cn(
      "group/input-group relative flex h-9 w-full items-center rounded-md border border-input bg-transparent shadow-xs transition-[color,box-shadow] focus-within:border-ring focus-within:ring-ring/50 focus-within:ring-[3px]",
      disabled && "opacity-50 cursor-not-allowed",
      className
    )}>
      <HeadlessComboboxInput
        className="flex-1 bg-transparent px-3 py-1 text-sm outline-none placeholder:text-muted-foreground disabled:cursor-not-allowed"
        placeholder={placeholder}
        displayValue={() => inputValue}
        onChange={(e) => setInputValue(e.target.value)}
        disabled={disabled}
      />
      <div className="flex items-center pr-1">
        {showClear && value && (
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault()
              e.stopPropagation()
              onValueChange(null)
              setInputValue("")
            }}
            className="rounded p-1 text-muted-foreground hover:text-foreground hover:bg-accent"
            disabled={disabled}
          >
            <XIcon className="size-4" />
          </button>
        )}
        {showTrigger && (
          <ComboboxButton className="rounded p-1 text-muted-foreground hover:text-foreground" disabled={disabled}>
            <ChevronDownIcon className="size-4" />
          </ComboboxButton>
        )}
      </div>
    </div>
  )
}

// Content/Options component
interface ComboboxContentProps {
  children: React.ReactNode
  className?: string
  disablePortal?: boolean // kept for API compatibility, not used with headlessui
}

function ComboboxContent({
  children,
  className,
}: ComboboxContentProps) {
  return (
    <ComboboxOptions
      modal
      className={cn(
        "absolute z-50 mt-1 max-h-60 w-full overflow-auto rounded-md bg-popover text-popover-foreground shadow-lg ring-1 ring-foreground/10 focus:outline-none",
        // Transition classes
        "transition duration-100 ease-out data-closed:opacity-0 data-closed:scale-95",
        className
      )}
    >
      {children}
    </ComboboxOptions>
  )
}

// List wrapper (for API compatibility)
interface ComboboxListProps {
  children: React.ReactNode
  className?: string
}

function ComboboxList({ children, className }: ComboboxListProps) {
  return (
    <div className={cn("p-1", className)}>
      {children}
    </div>
  )
}

// Item component
interface ComboboxItemProps {
  value: string
  children: React.ReactNode
  className?: string
  disabled?: boolean
}

function ComboboxItem({
  value,
  children,
  className,
  disabled = false,
}: ComboboxItemProps) {
  return (
    <ComboboxOption
      value={value}
      disabled={disabled}
      className={cn(
        "relative flex w-full cursor-default select-none items-center gap-2 rounded-sm py-1.5 pl-2 pr-8 text-sm outline-none",
        "data-focus:bg-accent data-focus:text-accent-foreground",
        "data-selected:bg-accent data-selected:text-accent-foreground",
        "data-disabled:pointer-events-none data-disabled:opacity-50",
        className
      )}
    >
      {({ selected }) => (
        <>
          {children}
          {selected && (
            <span className="absolute right-2 flex size-4 items-center justify-center">
              <CheckIcon className="size-4" />
            </span>
          )}
        </>
      )}
    </ComboboxOption>
  )
}

// Empty state (for API compatibility)
interface ComboboxEmptyProps {
  children: React.ReactNode
  className?: string
}

function ComboboxEmpty({ children, className }: ComboboxEmptyProps) {
  return (
    <div className={cn("py-2 text-center text-sm text-muted-foreground", className)}>
      {children}
    </div>
  )
}

// Separator
function ComboboxSeparator({ className }: { className?: string }) {
  return <div className={cn("my-1 h-px bg-border", className)} />
}

// Group components (for API compatibility)
function ComboboxGroup({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={cn(className)}>{children}</div>
}

function ComboboxLabel({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={cn("px-2 py-1.5 text-xs text-muted-foreground", className)}>
      {children}
    </div>
  )
}

// Passthrough components for API compatibility with alternative combobox implementations
function ComboboxCollection({ children }: { children: React.ReactNode }) {
  return <>{children}</>
}

function ComboboxValue({ children }: { children?: React.ReactNode }) {
  return <>{children}</>
}

function ComboboxTrigger({ children }: { children?: React.ReactNode }) {
  return <>{children}</>
}

function ComboboxChips({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={cn("flex flex-wrap gap-1", className)}>{children}</div>
}

function ComboboxChip({ children, className }: { children: React.ReactNode; className?: string }) {
  return <span className={cn("inline-flex items-center gap-1 rounded bg-muted px-2 py-0.5 text-xs", className)}>{children}</span>
}

function ComboboxChipsInput({ className }: { className?: string }) {
  return <input className={cn("flex-1 min-w-16 outline-none", className)} />
}

function useComboboxAnchor() {
  return React.useRef<HTMLDivElement | null>(null)
}

export {
  Combobox,
  ComboboxInput,
  ComboboxContent,
  ComboboxList,
  ComboboxItem,
  ComboboxGroup,
  ComboboxLabel,
  ComboboxCollection,
  ComboboxEmpty,
  ComboboxSeparator,
  ComboboxChips,
  ComboboxChip,
  ComboboxChipsInput,
  ComboboxTrigger,
  ComboboxValue,
  useComboboxAnchor,
}
