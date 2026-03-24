import { useLocation } from "react-router-dom";
import { useEffect } from "react";
import { Button } from "@/components/ui/button";

const NotFound = () => {
  const location = useLocation();

  useEffect(() => {
    console.error("404 Error: User attempted to access non-existent route:", location.pathname);
  }, [location.pathname]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="text-center space-y-4">
        <p className="font-script text-primary text-xl">Oops</p>
        <h1 className="font-display text-5xl font-bold text-foreground">404</h1>
        <p className="text-lg text-muted-foreground">This page doesn't exist.</p>
        <Button variant="cta" size="lg" asChild>
          <a href="/">Back to Home</a>
        </Button>
      </div>
    </div>
  );
};

export default NotFound;
