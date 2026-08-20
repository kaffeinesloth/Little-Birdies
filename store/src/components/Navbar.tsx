import React from 'react';
import { ShoppingCart, Search, User, Activity } from 'lucide-react';

export const Navbar: React.FC<{ cartCount: number; onOpenCart: () => void }> = ({ cartCount, onOpenCart }) => {
  return (
    <header className="bg-slate-950 text-white sticky top-0 z-40 border-b border-slate-800 shadow-md">
      <div className="max-w-7xl mx-auto px-4 py-3.5 flex justify-between items-center">
        {/* Brand Logo */}
        <div className="flex items-center gap-2.5">
          <div className="w-10 h-10 bg-gradient-to-tr from-sky-500 to-indigo-600 rounded-xl flex items-center justify-center text-white shadow-lg">
            <Activity className="w-6 h-6" />
          </div>
          <div>
            <h1 className="text-xl font-extrabold tracking-tight text-white flex items-center gap-1.5">
              SportGear <span className="text-sky-400 text-xs px-2 py-0.5 rounded bg-sky-950 border border-sky-800 font-bold">STORE</span>
            </h1>
            <p className="text-[10px] text-slate-400">Independent Sports Store (React + Tailwind)</p>
          </div>
        </div>

        {/* Navigation */}
        <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-slate-300">
          <a href="#" className="text-sky-400 font-semibold hover:text-sky-300 transition-colors">Home</a>
          <a href="#products" className="hover:text-white transition-colors">Men</a>
          <a href="#products" className="hover:text-white transition-colors">Women</a>
          <a href="#products" className="hover:text-white transition-colors">Equipment</a>
          <a href="#policy" className="hover:text-white transition-colors">Support Policy</a>
        </nav>

        {/* Action icons */}
        <div className="flex items-center gap-3">
          <button className="text-slate-400 hover:text-white transition-colors p-2 rounded-full hover:bg-slate-800 cursor-pointer">
            <Search className="w-5 h-5" />
          </button>
          <button className="text-slate-400 hover:text-white transition-colors p-2 rounded-full hover:bg-slate-800 cursor-pointer">
            <User className="w-5 h-5" />
          </button>
          <button
            onClick={onOpenCart}
            className="relative text-slate-200 hover:text-white bg-slate-800 hover:bg-slate-700 transition-colors p-2.5 rounded-full cursor-pointer flex items-center gap-1.5"
            title="View cart"
          >
            <ShoppingCart className="w-5 h-5" />
            {cartCount > 0 && (
              <span className="bg-sky-500 text-white font-black text-[11px] rounded-full px-2 py-0.5 shadow-md">
                {cartCount}
              </span>
            )}
          </button>
        </div>
      </div>
    </header>
  );
};
