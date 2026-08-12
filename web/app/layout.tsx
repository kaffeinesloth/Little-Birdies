import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Smart Helpdesk",
  description: "AI-powered customer support workspace for online shops"
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
