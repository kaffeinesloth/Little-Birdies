import React from 'react';
import type { Product } from '../types';
import { ShoppingCart, MessageCircleQuestion } from 'lucide-react';

interface ProductCardProps {
  product: Product;
  onAddToCart: (p: Product) => void;
  onAskAI: (question: string) => void;
}

export const ProductCard: React.FC<ProductCardProps> = ({ product, onAddToCart, onAskAI }) => {
  return (
    <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm hover:shadow-md transition-all flex flex-col justify-between group">
      <div>
        {/* Image / Icon container */}
        <div className="bg-slate-100 h-48 flex items-center justify-center relative overflow-hidden group-hover:bg-slate-50 transition-colors">
          {product.discount && (
            <span className="absolute top-3 left-3 bg-rose-600 text-white text-[11px] font-extrabold px-2.5 py-1 rounded-full shadow-sm z-10">
              {product.discount}
            </span>
          )}
          {product.tag && (
            <span className="absolute top-3 right-3 bg-sky-600 text-white text-[11px] font-extrabold px-2.5 py-1 rounded-full shadow-sm z-10">
              {product.tag}
            </span>
          )}
          <span className="text-6xl text-slate-700 group-hover:scale-110 transition-transform duration-300">
            {product.icon}
          </span>
        </div>

        {/* Content */}
        <div className="p-4">
          <span className="text-[11px] font-bold text-sky-600 uppercase tracking-wider block mb-1">
            {product.category}
          </span>
          <h4 className="font-bold text-slate-900 text-base mb-1 group-hover:text-sky-600 transition-colors line-clamp-1">
            {product.name}
          </h4>
          <p className="text-xs text-slate-500 mb-3 line-clamp-2 leading-relaxed">
            {product.description}
          </p>

          <div className="flex items-baseline gap-2 mb-4">
            <span className="text-lg font-black text-slate-900">
              {product.price.toLocaleString('vi-VN')}đ
            </span>
            {product.originalPrice && (
              <span className="text-xs text-slate-400 line-through">
                {product.originalPrice.toLocaleString('vi-VN')}đ
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="p-4 pt-0 grid grid-cols-2 gap-2">
        <button
          onClick={() => onAddToCart(product)}
          className="bg-sky-600 hover:bg-sky-700 text-white font-bold py-2 px-3 rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors shadow-sm"
        >
          <ShoppingCart className="w-3.5 h-3.5" /> Thêm giỏ
        </button>
        <button
          onClick={() => onAskAI(`Tư vấn giúp mình về sản phẩm ${product.name} (chất liệu, bảo hành...)`)}
          className="bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold py-2 px-3 rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors border border-slate-200"
        >
          <MessageCircleQuestion className="w-3.5 h-3.5 text-sky-600" /> Hỏi AI
        </button>
      </div>
    </div>
  );
};
