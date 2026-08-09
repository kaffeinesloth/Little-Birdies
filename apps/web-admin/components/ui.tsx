import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";

export function PageHeader({
  title,
  description,
  actions
}: {
  title: string;
  description: string;
  actions?: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-4 border-b border-line bg-white px-6 py-5 md:flex-row md:items-center md:justify-between">
      <div>
        <h1 className="text-xl font-semibold tracking-normal text-ink">{title}</h1>
        <p className="mt-1 max-w-3xl text-sm text-slate-600">{description}</p>
      </div>
      {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
    </div>
  );
}

export function Panel({
  title,
  children,
  right
}: {
  title: string;
  children: ReactNode;
  right?: ReactNode;
}) {
  return (
    <section className="border border-line bg-white shadow-panel">
      <div className="flex min-h-12 items-center justify-between border-b border-line px-4">
        <h2 className="text-sm font-semibold text-ink">{title}</h2>
        {right}
      </div>
      <div className="p-4">{children}</div>
    </section>
  );
}

export function Stat({
  label,
  value,
  delta,
  icon: Icon
}: {
  label: string;
  value: string;
  delta: string;
  icon?: LucideIcon;
}) {
  return (
    <div className="border border-line bg-white p-4 shadow-panel">
      <div className="flex items-center justify-between gap-3">
        <div className="text-xs font-medium uppercase text-slate-500">{label}</div>
        {Icon ? <Icon className="text-slate-400" size={17} /> : null}
      </div>
      <div className="mt-2 flex items-end justify-between">
        <div className="text-2xl font-semibold text-ink">{value}</div>
        <div className="text-sm font-medium text-brand">{delta}</div>
      </div>
    </div>
  );
}

export function StatusBadge({ value }: { value: string }) {
  const palette =
    value === "online" || value === "ready" || value === "resolved"
      ? "border-emerald-200 bg-emerald-50 text-emerald-800"
      : value === "pending" || value === "processing"
        ? "border-amber-200 bg-amber-50 text-amber-800"
        : value === "disabled"
          ? "border-rose-200 bg-rose-50 text-rose-800"
          : "border-slate-200 bg-slate-50 text-slate-700";

  return (
    <span className={`inline-flex items-center border px-2 py-0.5 text-xs font-medium ${palette}`}>
      {value.replace("_", " ")}
    </span>
  );
}
