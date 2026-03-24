import { DocumentQueue } from "@/components/DocumentQueue";

export default function Home() {
  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-black py-12 px-4">
      <div className="max-w-2xl mx-auto">
        <DocumentQueue />
      </div>
    </div>
  );
}
