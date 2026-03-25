import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { VIDEO_BACKUP } from "@/constants/videoIds";

const ADMIN_EMAILS = ["sls25trading@gmail.com", "emaildonovin@gmail.com"];

interface Customer {
  id: string;
  email: string;
  course_access: boolean;
  purchased_at: string | null;
}

interface PurchaseException {
  id: string;
  stripe_session_id: string;
  email: string;
  course_key: string;
  fulfillment_status: string;
  payment_status: string;
  amount_paid: number | null;
  currency: string | null;
  manual_review_reason: string | null;
  last_error: string | null;
  processed_at: string | null;
  created_at: string;
}

const Admin = () => {
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [exceptions, setExceptions] = useState<PurchaseException[]>([]);
  const [loadingData, setLoadingData] = useState(true);
  const [granting, setGranting] = useState<string | null>(null);
  const [rerunning, setRerunning] = useState<string | null>(null);
  const [reseeding, setReseeding] = useState(false);

  const isAdmin = user?.email && ADMIN_EMAILS.includes(user.email.toLowerCase());

  useEffect(() => {
    if (!loading && !user) navigate("/login");
    if (!loading && user && !isAdmin) navigate("/portal");
  }, [user, loading, isAdmin, navigate]);

  useEffect(() => {
    if (!isAdmin) return;
    fetchCustomers();
  }, [isAdmin]);

  const fetchCustomers = async () => {
    setLoadingData(true);
    const { data, error } = await supabase.functions.invoke("grant-access", {
      body: { action: "list" },
    });
    if (error) {
      console.error(error);
      toast.error("Failed to load customers");
    } else {
      setCustomers(data?.customers ?? []);
      setExceptions(data?.exceptions ?? []);
    }
    setLoadingData(false);
  };

  const handleGrant = async (customerId: string, email: string) => {
    setGranting(customerId);
    const { data, error } = await supabase.functions.invoke("grant-access", {
      body: { action: "grant", customerId, email },
    });
    if (error || !data?.success) {
      toast.error(data?.error ?? "Failed to grant access");
    } else {
      toast.success(`Access granted & magic link sent to ${email}`);
      fetchCustomers();
    }
    setGranting(null);
  };

  const handleRerun = async (purchase: PurchaseException) => {
    setRerunning(purchase.id);
    const { data, error } = await supabase.functions.invoke("grant-access", {
      body: { action: "rerun", purchaseId: purchase.id, sessionId: purchase.stripe_session_id },
    });
    if (error || !data?.success) {
      toast.error(data?.error ?? "Failed to rerun fulfillment");
    } else {
      toast.success(`Reran ${purchase.email}`);
      fetchCustomers();
    }
    setRerunning(null);
  };

  const handleReseed = async () => {
    setReseeding(true);
    const { data, error } = await supabase.functions.invoke("grant-access", {
      body: { action: "reseed", videos: VIDEO_BACKUP },
    });
    if (error || !data?.success) {
      toast.error("Failed to re-seed video IDs");
    } else {
      toast.success(`Re-seeded ${data.count} videos from backup`);
    }
    setReseeding(false);
  };

  if (loading || !isAdmin) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <p className="text-muted-foreground">Loading...</p>
      </div>
    );
  }

  const pending = customers.filter((c) => !c.course_access);
  const active = customers.filter((c) => c.course_access);

  return (
    <div className="min-h-screen bg-background">
      <header className="mx-auto max-w-5xl px-4 py-6 flex items-center justify-between">
        <span className="font-display text-xl font-semibold text-foreground">Admin Panel</span>
        <Button variant="outline" size="sm" onClick={() => navigate("/portal")}>
          Back to Portal
        </Button>
      </header>

      <main className="mx-auto max-w-5xl px-4 py-8 space-y-10">
        {loadingData ? (
          <p className="text-muted-foreground text-center">Loading customers...</p>
        ) : (
          <>
            {/* Exceptions */}
            <section>
              <h2 className="font-display text-2xl font-semibold text-foreground mb-4">
                Exceptions ({exceptions.length})
              </h2>
              {exceptions.length === 0 ? (
                <p className="text-muted-foreground">No fulfillment exceptions.</p>
              ) : (
                <div className="space-y-3">
                  {exceptions.map((purchase) => (
                    <div
                      key={purchase.id}
                      className="flex flex-col gap-4 rounded-lg border border-destructive/20 bg-destructive/5 p-4 sm:flex-row sm:items-center sm:justify-between"
                    >
                      <div className="space-y-1">
                        <p className="font-medium text-foreground">{purchase.email}</p>
                        <p className="text-sm text-muted-foreground">
                          {purchase.fulfillment_status} · {purchase.payment_status} · {purchase.stripe_session_id}
                        </p>
                        <p className="text-sm text-muted-foreground">
                          {purchase.manual_review_reason || purchase.last_error || "No error details saved"}
                        </p>
                      </div>
                      <Button
                        variant="cta"
                        size="sm"
                        disabled={rerunning === purchase.id}
                        onClick={() => handleRerun(purchase)}
                      >
                        {rerunning === purchase.id ? "Rerunning..." : "Rerun Fulfillment"}
                      </Button>
                    </div>
                  ))}
                </div>
              )}
            </section>

            {/* Pending */}
            <section>
              <h2 className="font-display text-2xl font-semibold text-foreground mb-4">
                Pending Access ({pending.length})
              </h2>
              {pending.length === 0 ? (
                <p className="text-muted-foreground">No pending customers.</p>
              ) : (
                <div className="space-y-3">
                  {pending.map((c) => (
                    <div
                      key={c.id}
                      className="flex items-center justify-between rounded-lg bg-card border border-border p-4"
                    >
                      <div>
                        <p className="text-foreground font-medium">{c.email}</p>
                        <p className="text-sm text-muted-foreground">
                          {c.purchased_at
                            ? `Purchased ${new Date(c.purchased_at).toLocaleDateString()}`
                            : "No purchase date"}
                        </p>
                      </div>
                      <Button
                        variant="cta"
                        size="sm"
                        disabled={granting === c.id}
                        onClick={() => handleGrant(c.id, c.email)}
                      >
                        {granting === c.id ? "Granting..." : "Grant Access"}
                      </Button>
                    </div>
                  ))}
                </div>
              )}
            </section>

            {/* Active */}
            <section>
              <h2 className="font-display text-2xl font-semibold text-foreground mb-4">
                Active Customers ({active.length})
              </h2>
              {active.length === 0 ? (
                <p className="text-muted-foreground">No active customers yet.</p>
              ) : (
                <div className="space-y-3">
                  {active.map((c) => (
                    <div
                      key={c.id}
                      className="flex items-center justify-between rounded-lg bg-card border border-border p-4"
                    >
                      <div>
                        <p className="text-foreground font-medium">{c.email}</p>
                        <p className="text-sm text-muted-foreground">
                          {c.purchased_at
                            ? `Since ${new Date(c.purchased_at).toLocaleDateString()}`
                            : "Active"}
                        </p>
                      </div>
                      <span className="text-sm text-[hsl(var(--success))] font-medium">✓ Active</span>
                    </div>
                  ))}
                </div>
              )}
            </section>

            {/* Disaster Recovery */}
            <section className="border-t border-border pt-8">
              <h2 className="font-display text-2xl font-semibold text-foreground mb-2">
                Disaster Recovery
              </h2>
              <p className="text-sm text-muted-foreground mb-4">
                If video data is missing from the database, click below to restore all 25 video IDs from the hardcoded backup.
              </p>
              <Button
                variant="outline"
                disabled={reseeding}
                onClick={handleReseed}
              >
                {reseeding ? "Re-seeding..." : "Re-seed Video IDs from Backup"}
              </Button>
            </section>
          </>
        )}
      </main>
    </div>
  );
};

export default Admin;
