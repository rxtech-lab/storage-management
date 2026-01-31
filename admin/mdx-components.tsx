import type { MDXComponents } from "mdx/types";

export function useMDXComponents(components: MDXComponents): MDXComponents {
  return {
    h1: ({ children }) => (
      <h1 className="text-3xl font-bold tracking-tight mb-6">{children}</h1>
    ),
    h2: ({ children }) => (
      <h2 className="text-2xl font-semibold tracking-tight mt-8 mb-4">
        {children}
      </h2>
    ),
    h3: ({ children }) => (
      <h3 className="text-xl font-semibold tracking-tight mt-6 mb-3">
        {children}
      </h3>
    ),
    p: ({ children }) => (
      <p className="leading-7 [&:not(:first-child)]:mt-4">{children}</p>
    ),
    ul: ({ children }) => <ul className="my-4 ml-6 list-disc">{children}</ul>,
    ol: ({ children }) => (
      <ol className="my-4 ml-6 list-decimal">{children}</ol>
    ),
    li: ({ children }) => <li className="mt-2">{children}</li>,
    a: ({ href, children }) => (
      <a
        href={href}
        className="text-primary underline underline-offset-4 hover:text-primary/80"
      >
        {children}
      </a>
    ),
    strong: ({ children }) => (
      <strong className="font-semibold">{children}</strong>
    ),
    blockquote: ({ children }) => (
      <blockquote className="mt-4 border-l-2 pl-6 italic">{children}</blockquote>
    ),
    ...components,
  };
}
