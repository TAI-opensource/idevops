"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { AlertTriangle, RefreshCw, Home } from "lucide-react";

export default function ErrorPage({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="flex min-h-[60vh] items-center justify-center p-4">
      <Card className="w-full max-w-lg">
        <CardHeader>
          <div className="text-destructive flex items-center gap-2">
            <AlertTriangle className="h-6 w-6" />
            <CardTitle>Erro na aplicação</CardTitle>
          </div>
          <CardDescription>Ocorreu um erro inesperado. Por favor, tente novamente.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="bg-muted rounded-md p-4">
            <p className="text-muted-foreground font-mono text-sm">
              {error.message || "Erro desconhecido"}
            </p>
            {error.digest && (
              <p className="text-muted-foreground mt-2 text-xs">Digest: {error.digest}</p>
            )}
          </div>
        </CardContent>
        <CardFooter className="flex gap-2">
          <Button variant="outline" onClick={() => (window.location.href = "/")}>
            <Home className="mr-2 h-4 w-4" />
            Início
          </Button>
          <Button onClick={() => reset()}>
            <RefreshCw className="mr-2 h-4 w-4" />
            Tentar novamente
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
}
