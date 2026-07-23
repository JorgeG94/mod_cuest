/*
 * oracle_report.h -- shared reporting for the C reference oracles.
 *
 * NVIDIA's cuEST samples compute their results and exit without printing them,
 * so there is nothing to diff a Fortran port against. Each oracle is a copy of
 * an upstream sample with calls to these helpers added and NOTHING else
 * changed, which keeps it a reference rather than a reimplementation.
 *
 * The output format is matched exactly by the Fortran side
 * (fortran_examples/common/cuest_sample_utils.f90) and parsed by compare.py.
 * If you change a format here, change it in all three places.
 *
 * Quantities are chosen to be sensitive to basis ordering and to any error in
 * the setup path, while staying independent of matrix size.
 */
#ifndef ORACLE_REPORT_H
#define ORACLE_REPORT_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <cuda_runtime.h>

static double *oracle_pull(const double *d_A, size_t n)
{
    double *a = (double *) malloc(n * sizeof(double));
    if (!a) {
        fprintf(stderr, "oracle_report: out of memory\n");
        exit(EXIT_FAILURE);
    }
    /* Accept a host pointer too, so callers need not care where data lives. */
    struct cudaPointerAttributes attr;   /* `struct` required: this is C, not C++ */
    if (cudaPointerGetAttributes(&attr, d_A) == cudaSuccess &&
        attr.type == cudaMemoryTypeDevice) {
        if (cudaMemcpy(a, d_A, n * sizeof(double),
                       cudaMemcpyDeviceToHost) != cudaSuccess) {
            fprintf(stderr, "oracle_report: cudaMemcpy failed\n");
            exit(EXIT_FAILURE);
        }
    } else {
        cudaGetLastError();                 /* clear the sticky query error */
        for (size_t i = 0; i < n; i++) a[i] = d_A[i];
    }
    return a;
}

static void oracle_rule(void) {
    printf("  ------------------------------------------------------------\n");
}

/* An n x n matrix, row-major, on the device or the host. */
static void oracle_report_matrix(const char *label, const double *A, uint64_t n)
{
    double *a = oracle_pull(A, (size_t) n * (size_t) n);
    double tr = 0.0, fro = 0.0, asym = 0.0;
    for (uint64_t i = 0; i < n; i++) {
        tr += a[i * n + i];
        for (uint64_t j = 0; j < n; j++) {
            fro += a[i * n + j] * a[i * n + j];
            double d = fabs(a[i * n + j] - a[j * n + i]);
            if (d > asym) asym = d;
        }
    }
    fro = sqrt(fro);
    uint64_t m = (n < 5) ? n : 5;
    oracle_rule();
    printf("  matrix %s\n", label);
    printf("    dimension      : %llu x %llu\n",
           (unsigned long long) n, (unsigned long long) n);
    printf("    trace          : %.14E\n", tr);
    printf("    Frobenius norm : %.14E\n", fro);
    printf("    max |A-A^T|    : %.2E\n", asym);
    printf("    leading %llu x %llu block:\n",
           (unsigned long long) m, (unsigned long long) m);
    for (uint64_t i = 0; i < m; i++) {
        for (uint64_t j = 0; j < m; j++) printf(" %14.9f", a[i * n + j]);
        printf("\n");
    }
    free(a);
}

/* A flat array of length n -- gradients, dipoles, charges, ... */
static void oracle_report_array(const char *label, const double *A, uint64_t n)
{
    double *a = oracle_pull(A, (size_t) n);
    double sum = 0.0, nrm = 0.0, amax = 0.0, l1 = 0.0;
    for (uint64_t i = 0; i < n; i++) {
        sum += a[i];
        l1  += fabs(a[i]);
        nrm += a[i] * a[i];
        if (fabs(a[i]) > amax) amax = fabs(a[i]);
    }
    nrm = sqrt(nrm);
    uint64_t m = (n < 12) ? n : 12;
    oracle_rule();
    printf("  array %s\n", label);
    printf("    length         : %llu\n", (unsigned long long) n);
    printf("    sum            : %.14E\n", sum);
    /* L1 is invariant under sign flips while `sum` is not: if two arrays agree
     * in norm and L1 but disagree in sum, the values are the same and some
     * signs differ -- an indexing or layout difference, not a precision one. */
    printf("    sum |a_i|      : %.14E\n", l1);
    printf("    norm           : %.14E\n", nrm);
    printf("    max |a_i|      : %.14E\n", amax);
    printf("    first %llu values:\n", (unsigned long long) m);
    for (uint64_t i = 0; i < m; i++) {
        printf(" %18.12f", a[i]);
        if ((i + 1) % 6 == 0 || i + 1 == m) printf("\n");
    }
    free(a);
}

/* A single number -- an energy, a trace, a count. */
static void oracle_report_scalar(const char *label, double v)
{
    oracle_rule();
    printf("  scalar %s\n", label);
    printf("    value          : %.14E\n", v);
}

#endif /* ORACLE_REPORT_H */
