package controllers

import (
	"fmt"

	"github.com/onsi/ginkgo/v2"
	"github.com/onsi/ginkgo/v2/config"
	"github.com/onsi/ginkgo/v2/types"
)

// This was taken from an older version of controller-runtime -
// https://github.com/kubernetes-sigs/controller-runtime/blob/c066edcfdcaeb6503e0c50cb7ed7fa82db15f130/pkg/envtest/printer/ginkgo.go
//
// This interface as such is not used in ginkgo >= 2.0, but this package still
// the 1.x series.

var _ ginkgo.Reporter = NewlineReporter{}

// NewlineReporter is Reporter that Prints a newline after the default Reporter output so that the results
// are correctly parsed by test automation.
// See issue https://github.com/jstemmer/go-junit-report/issues/31
type NewlineReporter struct{}

// SpecSuiteWillBegin implements ginkgo.Reporter.
func (NewlineReporter) SpecSuiteWillBegin(config config.GinkgoConfigType, summary *types.SuiteSummary) {
}

// BeforeSuiteDidRun implements ginkgo.Reporter.
func (NewlineReporter) BeforeSuiteDidRun(setupSummary *types.SetupSummary) {}

// AfterSuiteDidRun implements ginkgo.Reporter.
func (NewlineReporter) AfterSuiteDidRun(setupSummary *types.SetupSummary) {}

// SpecWillRun implements ginkgo.Reporter.
func (NewlineReporter) SpecWillRun(specSummary *types.SpecSummary) {}

// SpecDidComplete implements ginkgo.Reporter.
func (NewlineReporter) SpecDidComplete(specSummary *types.SpecSummary) {}

// SpecSuiteDidEnd Prints a newline between "35 Passed | 0 Failed | 0 Pending | 0 Skipped" and "--- PASS:".
func (NewlineReporter) SpecSuiteDidEnd(summary *types.SuiteSummary) { fmt.Printf("\n") }
