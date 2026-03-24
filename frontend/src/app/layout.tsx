import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { DocumentQueue } from "@/components/DocumentQueue";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Doxia Core - Document Processing",
  description: "Real-time document processing dashboard",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <main className="min-h-screen bg-gradient-to-b from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800 p-8">
          <div className="max-w-2xl mx-auto space-y-8">
            <header className="text-center space-y-2">
              <h1 className="text-4xl font-bold tracking-tight">Doxia Core</h1>
              <p className="text-muted-foreground">
                Real-time document processing monitor
              </p>
            </header>
            <DocumentQueue />
          </div>
        </main>
      </body>
    </html>
  );
}
