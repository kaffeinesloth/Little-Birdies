import { ShoppingBag, Star, Truck } from "lucide-react";
import { WebChatWidget } from "@/components/widget/web-chat-widget";

const products = [
  { name: "Wireless Headphones", price: "$89", note: "12-month warranty" },
  { name: "Travel Backpack", price: "$64", note: "Ships in 2 days" },
  { name: "Desk Lamp", price: "$42", note: "Free returns" }
];

export default function WidgetDemoPage() {
  return (
    <div className="min-h-[calc(100vh-56px)] bg-[#f8faf8] text-slate-900">
      <header className="border-b border-emerald-100 bg-white px-6 py-4">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex size-10 items-center justify-center bg-emerald-700 text-white">
              <ShoppingBag size={20} />
            </div>
            <div>
              <div className="text-lg font-semibold">Little Birdies Store</div>
              <div className="text-sm text-slate-500">Widget demo storefront</div>
            </div>
          </div>
          <div className="hidden items-center gap-2 text-sm text-slate-600 md:flex">
            <Truck size={17} />
            Same-week delivery on selected items
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-6 py-8">
        <section className="grid gap-6 lg:grid-cols-[1fr_360px]">
          <div className="bg-white p-6 shadow-panel">
            <div className="max-w-2xl">
              <div className="mb-3 inline-flex items-center gap-2 border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-medium text-emerald-800">
                <Star size={14} />
                Customer support preview
              </div>
              <h1 className="text-3xl font-semibold tracking-normal text-slate-950">
                Everyday essentials with fast support
              </h1>
              <p className="mt-3 text-sm leading-6 text-slate-600">
                This page demonstrates the embeddable Web Chat Widget. Try asking about shipping, warranty, or
                returns. Include words like refund, broken, late, or cancel to preview a handoff.
              </p>
            </div>
            <div className="mt-8 grid gap-4 md:grid-cols-3">
              {products.map((product) => (
                <article className="border border-slate-200 bg-white p-4" key={product.name}>
                  <div className="aspect-[4/3] bg-slate-100" />
                  <div className="mt-4 font-semibold text-slate-950">{product.name}</div>
                  <div className="mt-1 text-sm text-slate-500">{product.note}</div>
                  <div className="mt-4 flex items-center justify-between">
                    <span className="text-lg font-semibold text-emerald-800">{product.price}</span>
                    <button className="h-9 bg-slate-950 px-3 text-sm font-medium text-white" type="button">
                      Add
                    </button>
                  </div>
                </article>
              ))}
            </div>
          </div>

          <aside className="space-y-4">
            <div className="bg-white p-5 shadow-panel">
              <h2 className="text-sm font-semibold uppercase text-slate-500">Demo prompts</h2>
              <div className="mt-3 space-y-2 text-sm text-slate-700">
                <div className="border border-slate-200 p-3">How long is the warranty?</div>
                <div className="border border-slate-200 p-3">My delivery is late and I want a refund.</div>
                <div className="border border-slate-200 p-3">Type fail to preview a save error.</div>
              </div>
            </div>
            <div className="bg-white p-5 text-sm leading-6 text-slate-600 shadow-panel">
              The widget stores a local customer sender_id in browser storage and posts messages to the backend
              `/webhooks/web-message` endpoint in real mode. This demo runs with mocked backend responses.
            </div>
          </aside>
        </section>
      </main>

      <WebChatWidget customerName="Storefront visitor" mockBackend />
    </div>
  );
}
