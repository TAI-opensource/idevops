import Link from "next/link";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { FileQuestion, Home, ArrowLeft } from "lucide-react";

export default function NotFound() {
  return (
    <div className="flex min-h-[60vh] items-center justify-center p-4">
      <Card className="w-full max-w-lg">
        <CardHeader>
          <div className="flex items-center gap-2">
            <FileQuestion className="text-muted-foreground h-6 w-6" />
            <CardTitle>Página não encontrada</CardTitle>
          </div>
          <CardDescription>A página que você procura não existe ou foi movida.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-center">
            <span className="text-muted-foreground/20 text-8xl font-bold">404</span>
          </div>
        </CardContent>
        <CardFooter className="flex gap-2">
          <Button variant="outline" render={<Link href="/" />}>
            <Home className="mr-2 h-4 w-4" />
            Início
          </Button>
          <Button render={<Link href="javascript:history.back()" />}>
            <ArrowLeft className="mr-2 h-4 w-4" />
            Voltar
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
}
