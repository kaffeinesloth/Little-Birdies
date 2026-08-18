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
    name: 'Áo Polo Thể Thao Pro Active',
    category: 'Thời trang Nam',
    price: 320000,
    originalPrice: 400000,
    discount: '-20%',
    tag: 'BEST SELLER',
    icon: '👕',
    description: 'Chất liệu thun cá sấu dệt tổ ong thoáng khí cao cấp, co giãn 4 chiều, chống nhăn tuyệt đối.',
  },
  {
    id: 'p2',
    name: 'Giày Chạy Bộ Ultra Boost 2026',
    category: 'Giày Thể Thao',
    price: 1250000,
    originalPrice: 1500000,
    discount: '-16%',
    tag: 'HOT',
    icon: '👟',
    description: 'Đế đệm bọt nén Boost đàn hồi cao, giảm chấn tối đa cho runner chuyên nghiệp.',
  },
  {
    id: 'p3',
    name: 'Quần Short Tập Gym Co Giãn Gym Flex',
    category: 'Thời trang Nam',
    price: 210000,
    originalPrice: 260000,
    discount: '-19%',
    icon: '🩳',
    description: 'Vải dù sấy khô cực nhanh, siêu nhẹ, tích hợp túi khóa zip tiện lợi đựng điện thoại.',
  },
  {
    id: 'p4',
    name: 'Balo Thể Thao Chống Nước Oxford 25L',
    category: 'Phụ Kiện',
    price: 450000,
    icon: '🎒',
    description: 'Vải Oxford 900D chống thấm nước tuyệt đối, có ngăn laptop 15.6 inch + ngăn giày riêng.',
  },
  {
    id: 'p5',
    name: 'Bình Giữ Nhiệt Thể Thao Inox 304 (1 Lít)',
    category: 'Dụng Cụ',
    price: 220000,
    tag: 'NEW',
    icon: '🧴',
    description: 'Inox 304 chuẩn y tế 2 lớp chân không, giữ lạnh 24 giờ và giữ nóng 12 giờ.',
  },
  {
    id: 'p6',
    name: 'Thảm Tập Yoga TPE Chống Trượt 8mm',
    category: 'Dụng Cụ',
    price: 350000,
    originalPrice: 420000,
    discount: '-16%',
    icon: '🧘',
    description: 'Chất liệu TPE sinh học thân thiện với môi trường, định tuyến 2 mặt bám sàn vượt trội.',
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
    const question = `Mình đang muốn mua các món: ${itemsSummary}. Shop tư vấn size chuẩn và tính tổng tiền kèm ưu đãi freeship giúp mình nhé!`;
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
                <Sparkles className="w-3.5 h-3.5" /> Bộ Sưu Tập Thể Thao 2026
              </span>
              <h3 className="text-2xl md:text-3xl font-extrabold text-slate-900 tracking-tight mt-1">
                Danh Sách Sản Phẩm Nổi Bật
              </h3>
            </div>
            <p className="text-xs text-slate-500 max-w-md bg-sky-50 border border-sky-200/80 p-3 rounded-2xl">
              💡 Bấm nút <strong className="text-sky-700">"Hỏi AI"</strong> ở bất kỳ sản phẩm nào để được tư vấn chọn size, chất liệu và kiểm tra tồn kho tức thì!
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
              Cam Kết Dịch Vụ Khách Hàng Chuẩn SportGear
            </h4>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              <div className="flex flex-col items-center text-center p-4 rounded-2xl bg-slate-50 border border-slate-100">
                <Truck className="w-8 h-8 text-sky-600 mb-3" />
                <h5 className="font-bold text-sm text-slate-900 mb-1">Giao Hàng Siêu Tốc</h5>
                <p className="text-xs text-slate-500">Miễn phí vận chuyển toàn quốc từ 500.000đ. Giao hỏa tốc 2h nội thành.</p>
              </div>
              <div className="flex flex-col items-center text-center p-4 rounded-2xl bg-slate-50 border border-slate-100">
                <RotateCcw className="w-8 h-8 text-sky-600 mb-3" />
                <h5 className="font-bold text-sm text-slate-900 mb-1">Đổi Trả 30 Ngày Tận Nhà</h5>
                <p className="text-xs text-slate-500">Hỗ trợ đổi size/màu 1-1 miễn phí tại nhà nếu không vừa vặn.</p>
              </div>
              <div className="flex flex-col items-center text-center p-4 rounded-2xl bg-slate-50 border border-slate-100">
                <ShieldCheck className="w-8 h-8 text-sky-600 mb-3" />
                <h5 className="font-bold text-sm text-slate-900 mb-1">Bảo Hành Chính Hãng</h5>
                <p className="text-xs text-slate-500">100% sản phẩm chính hãng, bảo hành 12 tháng mọi lỗi kỹ thuật.</p>
              </div>
              <div className="flex flex-col items-center text-center p-4 rounded-2xl bg-slate-50 border border-slate-100">
                <Headphones className="w-8 h-8 text-sky-600 mb-3" />
                <h5 className="font-bold text-sm text-slate-900 mb-1">AI CSKH Trực Tuyến 24/7</h5>
                <p className="text-xs text-slate-500">Tư vấn size tự động, kết nối trực tiếp chuyên viên CSKH khi cần.</p>
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
                  <h3 className="font-bold text-base">Giỏ Hàng Của Bạn ({cart.reduce((s, i) => s + i.quantity, 0)})</h3>
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
                    Đơn hàng của bạn đã đạt điều kiện FREESHIP 100% toàn quốc!
                  </div>
                ) : (
                  <div>
                    <p className="text-slate-700 mb-1.5 font-medium">
                      Mua thêm <strong className="text-sky-700 font-black">{missingForFreeship.toLocaleString('vi-VN')}đ</strong> để được <strong className="text-emerald-700 font-black">FREESHIP</strong> toàn quốc!
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
                    <p className="font-bold text-sm text-slate-600">Giỏ hàng của bạn đang trống</p>
                    <p className="text-xs text-slate-400 mt-1">Hãy chọn sản phẩm ưng ý để thêm vào giỏ nhé!</p>
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
                          {item.price.toLocaleString('vi-VN')}đ
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
                      <span>Tạm tính:</span>
                      <span className="font-bold text-slate-900">{totalAmount.toLocaleString('vi-VN')}đ</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Phí vận chuyển:</span>
                      <span className={isFreeship ? 'font-bold text-emerald-600' : 'font-bold text-slate-900'}>
                        {isFreeship ? 'MIỄN PHÍ' : '25.000đ'}
                      </span>
                    </div>
                    <div className="flex justify-between text-sm font-black text-slate-900 pt-2 border-t border-slate-200">
                      <span>Tổng thanh toán:</span>
                      <span className="text-sky-600 text-base">
                        {(totalAmount + (isFreeship ? 0 : 25000)).toLocaleString('vi-VN')}đ
                      </span>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-2 pt-1">
                    <button
                      onClick={handleConsultCartAI}
                      className="bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border border-indigo-200 font-bold py-2.5 px-3 rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
                    >
                      <Sparkles className="w-3.5 h-3.5 text-indigo-600" /> Nhờ AI Tư Vấn
                    </button>
                    <button
                      onClick={handleCheckout}
                      className="bg-gradient-to-r from-sky-600 to-indigo-600 hover:opacity-90 text-white font-bold py-2.5 px-3 rounded-xl text-xs flex items-center justify-center gap-1.5 transition-all shadow-md cursor-pointer"
                    >
                      Thanh Toán Thử
                    </button>
                  </div>

                  {checkoutSuccess && (
                    <div className="p-2.5 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl text-xs font-bold text-center animate-in fade-in">
                      🎉 Đã tạo đơn hàng thử nghiệm thành công! Cảm ơn bạn!
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
          <p>© 2026 SportGear Boutique. Hệ Thống Cửa Hàng Bán Hàng Độc Lập.</p>
          <div className="flex gap-6 text-slate-400">
            <a href="#" className="hover:text-white">Điều khoản sử dụng</a>
            <a href="#" className="hover:text-white">Chính sách bảo mật</a>
            <a href="#" className="hover:text-white">Liên hệ CSKH</a>
          </div>
        </div>
      </footer>

      {/* Floating Live Chat Widget */}
      <ChatWidget initialMessage={initialAIQuestion} />
    </div>
  );
}

export default App;
