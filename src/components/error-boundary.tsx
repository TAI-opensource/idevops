"use client";

import React, { Component } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { RefreshCw, Home, Bug } from "lucide-react";
import { captureException } from "@/lib/sentry";

interface Props {
  children: React.ReactNode;
  fallback?: React.ReactNode;
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error: Error | null;
  errorInfo: React.ErrorInfo | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null, errorInfo: null };
  }

  static getDerivedStateFromError(error: Error): Partial<State> {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    this.setState({ errorInfo });

    captureException(error, {
      componentStack: errorInfo.componentStack,
      digest: (error as Error & { digest?: string }).digest,
    });

    this.props.onError?.(error, errorInfo);
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null, errorInfo: null });
  };

  handleGoHome = () => {
    window.location.href = "/";
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <Card className="mx-auto mt-8 max-w-lg">
          <CardHeader>
            <div className="text-destructive flex items-center gap-2">
              <Bug className="h-6 w-6" />
              <CardTitle>Algo deu errado</CardTitle>
            </div>
            <CardDescription>
              Ocorreu um erro inesperado. Nossa equipe foi notificada.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="bg-muted rounded-md p-4">
              <p className="text-muted-foreground font-mono text-sm">
                {this.state.error?.message || "Erro desconhecido"}
              </p>
              {process.env.NODE_ENV === "development" && this.state.errorInfo && (
                <pre className="text-muted-foreground mt-2 max-h-40 overflow-auto text-xs">
                  {this.state.errorInfo.componentStack}
                </pre>
              )}
            </div>
          </CardContent>
          <CardFooter className="flex gap-2">
            <Button variant="outline" onClick={this.handleGoHome}>
              <Home className="mr-2 h-4 w-4" />
              Início
            </Button>
            <Button onClick={this.handleRetry}>
              <RefreshCw className="mr-2 h-4 w-4" />
              Tentar novamente
            </Button>
          </CardFooter>
        </Card>
      );
    }

    return this.props.children;
  }
}

export function withErrorBoundary<P extends object>(
  Component: React.ComponentType<P>,
  fallback?: React.ReactNode
) {
  const WrappedComponent = (props: P) => (
    <ErrorBoundary fallback={fallback}>
      <Component {...props} />
    </ErrorBoundary>
  );

  WrappedComponent.displayName = `withErrorBoundary(${Component.displayName || Component.name})`;

  return WrappedComponent;
}
