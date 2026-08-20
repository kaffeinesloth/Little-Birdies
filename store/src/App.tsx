import { useState } from 'react';
import { Navbar } from './components/Navbar';
import { Hero } from './components/Hero';
import { ProductCard } from './components/ProductCard';
import { ChatWidget } from './components/ChatWidget';
import type { Product } from './types';
import { ShieldCheck, Truck, RotateCcw, Headphones, ShoppingBag, X, Plus, Minus, Trash2, Sparkles, CheckCircle2 } from 'lucide-react';

const SAMPLE_PRODUCTS: Product[] = [
  {
    id: 'p1',
    name: 'Polo Pro Active',
    category: "Men's Apparel",
    price: 320000,
    originalPrice: 400000,
    discount: '-20%',
    tag: 'BEST SELLER',
    icon: '👕',
    description: 'Premium breathable honeycomb pique with four-way stretch and excellent wrinkle resistance.',
  },
  {
    id: 'p2',
    name: 'Ultra Boost 2026 Running Shoes',
    category: 'Athletic Shoes',
    price: 1250000,
    originalPrice: 1500000,
    discount: '-16%',
    tag: 'HOT',
    icon: '👟',
    description: 'Responsive Boost foam cushioning designed for maximum shock absorption on serious runs.',
  },
  {
    id: 'p3',
    name: 'Gym Flex Stretch Shorts',
    category: "Men's Apparel",
    price: 210000,
    originalPrice: 260000,
    discount: '-19%',
    icon: '🩳',
    description: 'Ultra-light quick-dry fabric with a secure zip pocket for your phone.',
  },
  {
    id: 'p4',
    name: 'Oxford 25L Waterproof Sports Backpack',
    category: 'Accessories',
    price: 450000,
    icon: '🎒',
    description: 'Water-resistant 900D Oxford fabric with a 15.6-inch laptop sleeve and separate shoe compartment.',
  },
  {
    id: 'p5',
    name: 'Stainless-Steel Sports Bottle (1 Liter)',
    category: 'Equipment',
    price: 220000,
    tag: 'NEW',
    icon: '🧴',
    description: 'Food-grade 304 stainless steel with double-wall vacuum insulation: cold for 24 hours, hot for 12.',
  },
  {
    id: 'p6',
    name: '8 mm Non-Slip TPE Yoga Mat',
    category: 'Equipment',
    price: 350000,
    originalPrice: 420000,
    discount: '-16%',
    icon: '🧘',
    description: 'Eco-friendly bio-based TPE with high-grip textures on both sides.',
  },
];

interface CartItem extends Product {
  quantity: number;
}

export function App() {
  const [cart, setCart] = useState<CartItem[]>([]);
  const [isCartOpen, setIsCartOpen] = useState(false);
  const [initialAIQuestion, setInitialAIQuestion] = useState<string>('');
  const [checkoutSuccess, setCheckoutSuccess] = useState(false);

  const handleAddToCart = (product: Product) => {
    setCart((prev) => {
      const existing = prev.find((item) => item.id === product.id);
      if (existing) {
        return prev.map((item) =>
          item.id === product.id ? { ...item, quantity: item.quantity + 1 } : item
        );
      }
      return [...prev, { ...product, quantity: 1 }];
    });
    setIsCartOpen(true);
  };

  const handleUpdateQuantity = (productId: string, delta: number) => {
    setCart((prev) =>
      prev
        .map((item) => {
          if (item.id === productId) {
            const newQty = item.quantity + delta;
            return newQty > 0 ? { ...item, quantity: newQty } : null;
          }
          return item;
        })
        .filter(Boolean) as CartItem[]
    );
  };

  const handleRemoveFromCart = (productId: string) => {
    setCart((prev) => prev.filter((item) => item.id !== productId));
  };

  const handleAskAI = (question: string) => {
    setInitialAIQuestion('');
    setTimeout(() => {
      setInitialAIQuestion(question);
    }, 50);
  };

  const totalAmount = cart.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const isFreeship = totalAmount >= 500000;
  const missingForFreeship = Math.max(0, 500000 - totalAmount);

  const handleConsultCartAI = () => {
    if (cart.length === 0) return;
    const itemsSummary = cart.map((i) => `${i.name} (SL: ${i.quantity})`).join(', ');
    const question = `I want to buy these items: ${itemsSummary}. Please recommend the right sizes and calculate the total with any free-shipping offer.`;
    setIsCartOpen(false);
    handleAskAI(question);
  };

  const handleCheckout = () => {
    setCheckoutSuccess(true);
    setTimeout(() => {
      setCheckoutSuccess(false);
      setCart([]);
      setIsCartOpen(false);
    }, 2500);
  };

  return (
    <div className="min-h-screen bg-slate-50 font-sans text-slate-800 flex flex-col justify-between">
      <div>
        {/* Navigation */}
        <Navbar cartCount={cart.reduce((s, i) => s + i.quantity, 0)} onOpenCart={() => setIsCartOpen(true)} />

        {/* Hero Section */}
        <Hero />

        {/* Products Section */}
        <main id="products" className="max-w-7xl mx-auto px-4 py-12">
          <div className="flex flex-col md:flex-row justify-between items-start md:items-end mb-8 gap-4">
            <div>
              <span className="text-xs font-bold text-sky-600 uppercase tracking-widest flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5" /> 2026 Sports Collection
              </span>
              <h3 className="text-2xl md:text-3xl font-extrabold text-slate-900 tracking-tight mt-1">
                Featured Products
              </h3>
            </div>
            <p className="text-xs text-slate-500 max-w-md bg-sky-50 border border-sky-200/80 p-3 rounded-2xl">
              💡 Select <strong className="text-sky-700">"Ask AI"</strong> on any product for instant sizing, materials, and stock advice.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
            {SAMPLE_PRODUCTS.map((p) => (
              <ProductCard
                key={p.id}
                product={p}
                onAddToCart={handleAddToCart}
                onAskAI={handleAskAI}
              />
            ))}
          </div>

          {/* Policy Section */}
          <section id="policy" className="mt-16 bg-white rounded-3xl p-8 border border-slate-200 shadow-sm">
            <h4 className="text-xl font-bold text-slate-900 mb-6 text-center">
              The SportGear Service Promise
            </h4>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              <div className="flex flex-col items-center text-center p-4 rounded-2xl bg-slate-50 border border-slate-100">
                <Truck className="w-8 h-8 text-sky-600 mb-3" />
                <h5 className="font-bold text-sm text-slate-900 mb-1">Fast Delivery</h5>
                <p className="text-xs text-slate-500">Free nationwide shipping from 500,000 VND. Two-hour delivery in the city.</p>
              </div>
              <div className="flex flex-col items-center text-center p-4 rounded-2xl bg-slate-50 border border-slate-100">
                <RotateCcw className="w-8 h-8 text-sky-600 mb-3" />
                <h5 className="font-bold text-sm text-slate-900 mb-1">30-Day At-Home Returns</h5>
                <p className="text-xs text-slate-500">Free one-for-one size or color exchanges at home when the fit is not right.</p>
              </div>
              <div className="flex flex-col items-center text-center p-4 rounded-2xl bg-slate-50 border border-slate-100">
                <ShieldCheck className="w-8 h-8 text-sky-600 mb-3" />
                <h5 className="font-bold text-sm text-slate-900 mb-1">Authenticity Guarantee</h5>
                <p className="text-xs text-slate-500">100% authentic products with a 12-month technical warranty.</p>
              </div>
              <div className="flex flex-col items-center text-center p-4 rounded-2xl bg-slate-50 border border-slate-100">
                <Headphones className="w-8 h-8 text-sky-600 mb-3" />
                <h5 className="font-bold text-sm text-slate-900 mb-1">24/7 AI Support</h5>
                <p className="text-xs text-slate-500">Automatic sizing advice with direct access to a live agent when needed.</p>
              </div>
            </div>
          </section>
        </main>
      </div>

      {/* Shopping Cart Drawer */}
      {isCartOpen && (
        <div className="fixed inset-0 z-50 overflow-hidden">
          <div
            className="absolute inset-0 bg-slate-950/60 backdrop-blur-xs transition-opacity"
            onClick={() => setIsCartOpen(false)}
          />
          <div className="fixed inset-y-0 right-0 max-w-full flex pl-10">
            <div className="w-screen max-w-md bg-white shadow-2xl flex flex-col">
              {/* Header */}
              <div className="p-4 bg-slate-950 text-white flex justify-between items-center">
                <div className="flex items-center gap-2">
                  <ShoppingBag className="w-5 h-5 text-sky-400" />
                  <h3 className="font-bold text-base">Your Cart ({cart.reduce((s, i) => s + i.quantity, 0)})</h3>
                </div>
                <button
                  onClick={() => setIsCartOpen(false)}
                  className="text-slate-400 hover:text-white p-1 rounded-full hover:bg-slate-800 cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Freeship Progress Banner */}
              <div className="bg-sky-50 border-b border-sky-200 p-3 text-xs">
                {isFreeship ? (
                  <div className="flex items-center gap-1.5 font-bold text-emerald-700">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                    Your order qualifies for free nationwide shipping!
                  </div>
                ) : (
                  <div>
                    <p className="text-slate-700 mb-1.5 font-medium">
                      Add <strong className="text-sky-700 font-black">{missingForFreeship.toLocaleString('en-US')} VND</strong> more for <strong className="text-emerald-700 font-black">FREE</strong> nationwide shipping.
                    </p>
                    <div className="w-full bg-slate-200 rounded-full h-2 overflow-hidden">
                      <div
                        className="bg-sky-500 h-full rounded-full transition-all duration-500"
                        style={{ width: `${Math.min(100, (totalAmount / 500000) * 100)}%` }}
                      />
                    </div>
                  </div>
                )}
              </div>

              {/* Cart Items List */}
              <div className="flex-1 overflow-y-auto p-4 space-y-3">
                {cart.length === 0 ? (
                  <div className="text-center py-16 text-slate-400">
                    <ShoppingBag className="w-12 h-12 mx-auto mb-3 text-slate-300 stroke-[1.5]" />
                    <p className="font-bold text-sm text-slate-600">Your cart is empty</p>
                    <p className="text-xs text-slate-400 mt-1">Choose a product to add it to your cart.</p>
                  </div>
                ) : (
                  cart.map((item) => (
                    <div
                      key={item.id}
                      className="flex items-center gap-3 p-3 bg-slate-50 rounded-2xl border border-slate-200"
                    >
                      <div className="w-14 h-14 bg-white rounded-xl flex items-center justify-center text-2xl border border-slate-200 shrink-0 shadow-2xs">
                        {item.icon}
                      </div>
                      <div className="flex-1 min-w-0">
                        <h4 className="font-bold text-xs text-slate-900 truncate">{item.name}</h4>
                        <p className="text-xs text-sky-600 font-extrabold mt-0.5">
                          {item.price.toLocaleString('en-US')} VND
                        </p>
                        <div className="flex items-center gap-2 mt-2">
                          <div className="flex items-center border border-slate-300 rounded-lg bg-white overflow-hidden">
                            <button
                              onClick={() => handleUpdateQuantity(item.id, -1)}
                              className="px-2 py-0.5 hover:bg-slate-100 text-slate-600 cursor-pointer"
                            >
                              <Minus className="w-3 h-3" />
                            </button>
                            <span className="px-2 text-xs font-bold text-slate-800">{item.quantity}</span>
                            <button
                              onClick={() => handleUpdateQuantity(item.id, 1)}
                              className="px-2 py-0.5 hover:bg-slate-100 text-slate-600 cursor-pointer"
                            >
                              <Plus className="w-3 h-3" />
                            </button>
                          </div>
                        </div>
                      </div>
                      <button
                        onClick={() => handleRemoveFromCart(item.id)}
                        className="text-slate-400 hover:text-rose-600 p-1.5 rounded-lg hover:bg-rose-50 transition-colors cursor-pointer"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  ))
                )}
              </div>

              {/* Footer Summary & Actions */}
              {cart.length > 0 && (
                <div className="p-4 bg-slate-50 border-t border-slate-200 space-y-3">
                  <div className="space-y-1.5 text-xs text-slate-600">
                    <div className="flex justify-between">
                      <span>Subtotal:</span>
                      <span className="font-bold text-slate-900">{totalAmount.toLocaleString('en-US')} VND</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Shipping:</span>
                      <span className={isFreeship ? 'font-bold text-emerald-600' : 'font-bold text-slate-900'}>
                        {isFreeship ? 'FREE' : '25,000 VND'}
                      </span>
                    </div>
                    <div className="flex justify-between text-sm font-black text-slate-900 pt-2 border-t border-slate-200">
                      <span>Total:</span>
                      <span className="text-sky-600 text-base">
                        {(totalAmount + (isFreeship ? 0 : 25000)).toLocaleString('en-US')} VND
                      </span>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-2 pt-1">
                    <button
                      onClick={handleConsultCartAI}
                      className="bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border border-indigo-200 font-bold py-2.5 px-3 rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
                    >
                      <Sparkles className="w-3.5 h-3.5 text-indigo-600" /> Ask AI About Cart
                    </button>
                    <button
                      onClick={handleCheckout}
                      className="bg-gradient-to-r from-sky-600 to-indigo-600 hover:opacity-90 text-white font-bold py-2.5 px-3 rounded-xl text-xs flex items-center justify-center gap-1.5 transition-all shadow-md cursor-pointer"
                    >
                      Demo Checkout
                    </button>
                  </div>

                  {checkoutSuccess && (
                    <div className="p-2.5 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl text-xs font-bold text-center animate-in fade-in">
                      🎉 Demo order created successfully. Thank you!
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Footer */}
      <footer className="bg-slate-950 text-slate-400 border-t border-slate-800 py-10 px-4 text-xs">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-4">
          <p>© 2026 SportGear Boutique. Independent Demo Store.</p>
          <div className="flex gap-6 text-slate-400">
            <a href="#" className="hover:text-white">Terms of Use</a>
            <a href="#" className="hover:text-white">Privacy Policy</a>
            <a href="#" className="hover:text-white">Contact Support</a>
          </div>
        </div>
      </footer>

      {/* Floating Live Chat Widget */}
      <ChatWidget initialMessage={initialAIQuestion} />
    </div>
  );
}

export default App;
