"use client";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { getImageUploadUrlAction } from "@/lib/actions/s3-upload-actions";
import { ItemAIResponseSchema, type ItemAIResponse } from "@/lib/schemas/item-ai";

export interface AppliedItemDraft {
  response: ItemAIResponse;
  images: string[];
  selectedTags: string[];
  categoryId: string | null;
  authorId: string | null;
  tagIds: string[];
}
interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  context: { title: string; description: string; originalQrCode: string; images: string[] };
  onApply: (draft: AppliedItemDraft) => void;
}
export function ItemAIDialog({ open, onOpenChange, context, onApply }: Props) {
  const [prompt, setPrompt] = useState("");
  const [webSearch, setWebSearch] = useState(true);
  const [images, setImages] = useState<string[]>([]);
  const [result, setResult] = useState<ItemAIResponse | null>(null);
  const [category, setCategory] = useState(false);
  const [author, setAuthor] = useState(false);
  const [tags, setTags] = useState<string[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  useEffect(() => {
    if (open) { setResult(null); setImages(context.images.slice(0, 5)); setPrompt(""); }
    // Capture the form when the dialog opens; edits in the dialog keep their own state.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);
  async function upload(files: FileList | null) {
    if (!files) return;
    const selected = Array.from(files);
    if (images.length + selected.length > 5) { toast.error("Attach up to 5 images"); return; }
    if (selected.some(file => !["image/jpeg", "image/png", "image/webp", "image/gif"].includes(file.type) || file.size > 10 * 1024 * 1024)) { toast.error("Choose JPEG, PNG, WebP, or GIF images up to 10 MB each"); return; }
    setBusy("Uploading images…");
    try {
      for (const file of selected) {
        const signed = await getImageUploadUrlAction(file.name, file.type, "items", undefined, file.size);
        if (!signed.success || !signed.data) throw new Error(signed.error || "Could not upload image");
        const response = await fetch(signed.data.uploadUrl, { method: "PUT", headers: { "Content-Type": file.type }, body: file });
        if (!response.ok) throw new Error("Image upload failed");
        const ref = `file:${signed.data.fileId}`;
        setImages(previous => [...previous, ref]);
      }
    } catch (error) { toast.error(error instanceof Error ? error.message : "Upload failed"); }
    finally { setBusy(null); }
  }
  async function generate() {
    setBusy(webSearch ? "Researching item online…" : "Drafting item…");
    try {
      const response = await fetch("/api/v1/items/ai", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ...context, prompt, images, webSearch }) });
      const body = await response.json();
      if (!response.ok) throw new Error(body.error || "Could not draft item");
      const parsed = ItemAIResponseSchema.parse(body);
      setResult(parsed); setCategory(false); setAuthor(false); setTags([]);
    } catch (error) { toast.error(error instanceof Error ? error.message : "Could not draft item"); }
    finally { setBusy(null); }
  }
  async function apply() {
    if (!result) return;
    setBusy("Applying draft…");
    try {
      let relations = { categoryId: null, authorId: null, tagIds: [] } as { categoryId: string | null; authorId: string | null; tagIds: string[] };
      if (category || author || tags.length) {
        const response = await fetch("/api/v1/items/ai/relations", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ category: category ? result.draft.category : null, author: author ? result.draft.author : null, tags }) });
        const body = await response.json();
        if (!response.ok) throw new Error(body.error || "Could not create suggestions");
        relations = body;
      }
      onApply({ response: result, images, selectedTags: tags, ...relations });
      onOpenChange(false);
      toast.success("Draft applied. Review the form before saving.");
    } catch (error) { toast.error(error instanceof Error ? error.message : "Could not apply draft"); }
    finally { setBusy(null); }
  }
  return <Dialog open={open} onOpenChange={value => { if (!busy) onOpenChange(value); }}>
    <DialogContent className="sm:max-w-xl max-h-[90vh] overflow-y-auto" showCloseButton={!busy} onEscapeKeyDown={e => { if (busy) e.preventDefault(); }} onPointerDownOutside={e => { if (busy) e.preventDefault(); }}>
      <DialogTitle>{result ? "Review AI draft" : "Create item using AI"}</DialogTitle>
      <DialogDescription>{result ? "Check the details and choose which related records to create or reuse." : "Describe the item or attach photos. AI can research details online."}</DialogDescription>
      {!result ? <>
        <Label htmlFor="item-ai-prompt">Item details</Label>
        <Textarea id="item-ai-prompt" data-testid="item-ai-prompt" value={prompt} onChange={e => setPrompt(e.target.value)} rows={5} placeholder="Describe the item, model, or ISBN…" />
        <Label htmlFor="item-ai-images">Attach images (up to 5)</Label>
        <Input id="item-ai-images" type="file" accept="image/jpeg,image/png,image/webp,image/gif" multiple disabled={!!busy || images.length >= 5} onChange={e => { void upload(e.target.files); e.target.value = ""; }} />
        {images.map((image, index) => <div key={image} className="flex items-center justify-between"><span>Attached image {index + 1}</span><Button type="button" variant="ghost" onClick={() => setImages(previous => previous.filter(ref => ref !== image))}>Remove image {index + 1}</Button></div>)}
        <label className="flex items-center gap-2"><input type="checkbox" checked={webSearch} onChange={e => setWebSearch(e.target.checked)} />Search the web for item information</label>
        <Button type="button" onClick={() => void generate()} disabled={!!busy || !(prompt.trim() || context.title || context.originalQrCode || images.length)}>Generate draft</Button>
      </> : <>
        <Label htmlFor="ai-draft-title">Title</Label><Input id="ai-draft-title" value={result.draft.title} onChange={e => setResult({ ...result, draft: { ...result.draft, title: e.target.value } })} />
        <Label htmlFor="ai-draft-description">Description</Label><Textarea id="ai-draft-description" rows={5} value={result.draft.description} onChange={e => setResult({ ...result, draft: { ...result.draft, description: e.target.value } })} />
        {result.draft.category && <label><input type="checkbox" checked={category} onChange={e => setCategory(e.target.checked)} /> Create or reuse category: {result.draft.category}</label>}
        {result.draft.author && <label><input type="checkbox" checked={author} onChange={e => setAuthor(e.target.checked)} /> Create or reuse author: {result.draft.author}</label>}
        {result.draft.tags.map(tag => <label key={tag}><input type="checkbox" checked={tags.includes(tag)} onChange={e => setTags(previous => e.target.checked ? [...previous, tag] : previous.filter(t => t !== tag))} /> Create or reuse tag: {tag}</label>)}
        {result.sources.length > 0 && <div><p className="font-medium">Sources</p>{result.sources.map(source => <a className="block underline" key={source.url} href={source.url} target="_blank" rel="noopener noreferrer">{source.title}</a>)}</div>}
        <div className="flex gap-2"><Button type="button" variant="outline" onClick={() => setResult(null)}>Back</Button><Button type="button" disabled={!!busy || !result.draft.title.trim()} onClick={() => void apply()}>Apply draft</Button></div>
      </>}
      {busy && <div role="status" className="absolute inset-0 z-10 grid place-items-center bg-background/95 rounded-xl">{busy}</div>}
    </DialogContent>
  </Dialog>;
}
