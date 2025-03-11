"use client";

import { Suspense, useEffect, useState } from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Toaster } from "@/components/ui/toaster";
import { Disclaimer } from "@/components/ui/disclaimer";
import { useSearchParams } from "next/navigation";
import { useTransactionCalculation } from "@/hooks/use-transaction-calculation";
import StepperTransactionForm from "@/components/transaction/StepperTransactionForm";
import ResultCard from "@/components/ResultCard";
import Link from "next/link";

function HomeContent() {
  const searchParams = useSearchParams();
  
  const {
    form,
    result,
    isLoading,
    calculationRequested,
    handleSubmit,
    step,
    nextStep,
    prevStep,
  } = useTransactionCalculation(searchParams);

  const [lastMethod, setLastMethod] = useState(form.watch("method"));
  const [showResult, setShowResult] = useState(false);
  
  useEffect(() => {
    const currentMethod = form.watch("method");
    
    if (currentMethod !== lastMethod) {
      setShowResult(false);
      setLastMethod(currentMethod);
    }
    
    setShowResult(calculationRequested && (currentMethod === "api" || step >= 4));
  }, [calculationRequested, step, form, lastMethod]);

  const renderResultCard = () => {
    if (!showResult) return null;
    return <ResultCard result={result} isLoading={isLoading} />;
  };

  return (
    <>
      <Toaster />
      <div className="flex flex-col w-full justify-center items-center p-5">
        <h1 className="text-[48px] font-semibold text-center mb-8 dark:text-title-dark text-title-light">
          Safe Utils
        </h1>
        <div className="text-center max-w-2xl mb-8">
          <p className="text-muted-foreground">
            Verify Safe transaction hashes before signing and executing. Calculate domain, message, and 
            transaction hashes based on EIP-712 standard.{" "}
            <Link href="/how-it-works" className="text-primary hover:underline">
              Learn more.
            </Link>
          </p>
        </div>
        <Card className="rounded-[24px] sm:p-12 p-5 dark:bg-card-dark bg-card-light w-full sm:w-[620px] mx-4">
          <CardHeader className="flex flex-col items-center">
          <div className="flex items-center gap-2 mb-4 justify-center">
            <Disclaimer className="text-muted-foreground hover:text-foreground text-[14px] flex items-center font-normal">
              Disclaimer
            </Disclaimer>
          </div>
          </CardHeader>
          <CardContent>
            <StepperTransactionForm 
              form={form}
              onSubmit={handleSubmit}
              isLoading={isLoading}
              step={step}
              nextStep={nextStep}
              prevStep={prevStep}
            />
          </CardContent>
        </Card>
        {renderResultCard()}
      </div>
    </>
  );
}

// Loading fallback component
function LoadingFallback() {
  return (
    <div className="flex flex-col w-full justify-center items-center p-5">
      <h1 className="text-[48px] font-semibold text-center mb-8 dark:text-title-dark text-title-light">
        Safe Utils
      </h1>
      <Card className="rounded-[24px] sm:p-16 p-5 dark:bg-card-dark bg-card-light w-full sm:w-[555px] mx-4">
        <CardHeader>
          <CardTitle>
            <Skeleton className="h-8 w-48" />
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-10 w-full" />
          </div>
          <Skeleton className="h-10 w-40 mt-6" />
        </CardContent>
      </Card>
    </div>
  );
}

export default function Home() {
  return (
    <Suspense fallback={<LoadingFallback />}>
      <HomeContent />
    </Suspense>
  );
}