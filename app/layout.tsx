import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TOPCLASS TRACK | Top Class Auto Body",
  description: "Repair tracking and customer management for Top Class Auto Body Zimbabwe.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
