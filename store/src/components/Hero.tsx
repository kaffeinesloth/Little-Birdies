import React from 'react';
import { ArrowRight, ShieldCheck, Zap, RefreshCw } from 'lucide-react';

export const Hero: React.FC = () => {
  return (
    <section className="bg-gradient-to-br from-slate-900 via-slate-950 to-indigo-950 text-white py-16 px-4 relative overflow-hidden border-b border-slate-800">
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-12 gap-8 items-center relative z-10">
        <div className="md:col-span-7 flex flex-col items-start gap-4">
          <span className="inline-flex items-center gap-2 bg-sky-950/80 border border-sky-500/30 text-sky-400 text-xs font-semibold px-3 py-1.5 rounded-full">
            <Zap className="w-3.5 h-3.5" /> Authentic Summer Sports Collection 2026
          </span>
          <h2 className="text-4xl md:text-5xl font-extrabold tracking-tight leading-tight text-white">
            Go Beyond Your Limits <br />
            With <span className="text-transparent bg-clip-text bg-gradient-to-r from-sky-400 to-indigo-400">SportGear Boutique</span>
          </h2>
          <p className="text-slate-300 text-sm md:text-base leading-relaxed max-w-xl">
            High-performance sportswear and training equipment with four-way stretch, excellent breathability,
            and flexible 30-day returns.
          </p>

          <div className="flex flex-wrap gap-4 mt-2">
            <a
              href="#products"
              className="bg-sky-500 hover:bg-sky-600 text-white font-bold px-6 py-3 rounded-xl transition-all shadow-lg hover:shadow-sky-500/25 flex items-center gap-2 text-sm"
            >
              Shop Products <ArrowRight className="w-4 h-4" />
            </a>
            <a
              href="#policy"
              className="bg-slate-800/80 hover:bg-slate-800 text-slate-200 font-semibold px-5 py-3 rounded-xl border border-slate-700 transition-all text-sm"
            >
              Warranty Policy
            </a>
          </div>

          {/* Badges */}
          <div className="grid grid-cols-3 gap-6 pt-6 mt-4 border-t border-slate-800/80 w-full max-w-lg">
            <div className="flex items-center gap-2.5">
              <ShieldCheck className="w-5 h-5 text-sky-400 shrink-0" />
              <div className="text-left">
                <p className="text-xs font-bold text-white">100% Authentic</p>
                <p className="text-[10px] text-slate-400">Quality guaranteed</p>
              </div>
            </div>
            <div className="flex items-center gap-2.5">
              <RefreshCw className="w-5 h-5 text-sky-400 shrink-0" />
              <div className="text-left">
                <p className="text-xs font-bold text-white">30-Day Returns</p>
                <p className="text-[10px] text-slate-400">Simple and fast</p>
              </div>
            </div>
            <div className="flex items-center gap-2.5">
              <Zap className="w-5 h-5 text-sky-400 shrink-0" />
              <div className="text-left">
                <p className="text-xs font-bold text-white">2-Hour Delivery</p>
                <p className="text-[10px] text-slate-400">Ho Chi Minh City</p>
              </div>
            </div>
          </div>
        </div>

        {/* Hero Visual Card */}
        <div className="md:col-span-5 flex justify-center">
          <div className="bg-gradient-to-tr from-sky-900/40 to-indigo-900/40 border border-sky-500/20 backdrop-blur-md rounded-3xl p-8 shadow-2xl relative w-full max-w-sm flex flex-col items-center text-center">
            <div className="w-32 h-32 bg-sky-500/20 rounded-full flex items-center justify-center mb-4 text-sky-400">
              <Zap className="w-16 h-16 animate-pulse" />
            </div>
            <span className="text-xs font-bold text-sky-400 tracking-widest uppercase mb-1">BST Pro-Fit 2026</span>
            <h3 className="text-xl font-extrabold text-white mb-2">Four-Way Stretch Sports Polo</h3>
            <div className="flex items-baseline gap-2 mb-4">
              <span className="text-2xl font-black text-sky-400">320,000 VND</span>
              <span className="text-sm text-slate-400 line-through">400,000 VND</span>
              <span className="text-xs bg-rose-500/20 border border-rose-500/30 text-rose-400 font-bold px-2 py-0.5 rounded">-20%</span>
            </div>
            <p className="text-xs text-slate-300 mb-6 leading-relaxed">
              Honeycomb pique fabric with fast moisture wicking.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
};
