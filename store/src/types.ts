export interface Product {
  id: string;
  name: string;
  category: string;
  price: number;
  originalPrice?: number;
  discount?: string;
  tag?: string;
  icon: string;
  description: string;
}

export interface ChatMessage {
  id: string;
  sender_type: 'customer' | 'bot' | 'human';
  content: string;
  created_at?: string;
}
