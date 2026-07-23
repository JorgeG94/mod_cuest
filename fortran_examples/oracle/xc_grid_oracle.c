/*
 * Derived from NVIDIA's cuEST C sample
 *   c_examples/examples/1_basic_data_structures/xc_grid/main.c
 * (Apache-2.0, Copyright (c) NVIDIA CORPORATION & AFFILIATES).
 *
 * MODIFIED, in three ways and no others:
 *   1. the sample's own molecule_definition.h is inlined verbatim below,
 *      because the oracle is built outside the sample directory and cannot
 *      include it;
 *   2. the radial quadrature and pruning arrays of each atom are reported with
 *      oracle_report_array() before their buffers are freed;
 *   3. the finished atom grids and molecular grid are queried for their
 *      documented attributes and reported with oracle_report_scalar().
 * The sample itself computes the grid and exits without printing anything, so
 * without (2) and (3) there would be nothing to compare. The setup path is
 * byte-identical to upstream, which is the point: it is the reference, not a
 * reimplementation.
 */
/*
 * SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#include <cuest.h>

#include <helper_status.h>
#include <helper_workspaces.h>

/* ADDED: shared reporting, so this oracle and the Fortran port
 * print the identical format that compare.py parses. */
#include "oracle_report.h"

/* ---------------------------------------------------------------------------
 * INLINED verbatim from the sample's own molecule_definition.h, which lives
 * next to main.c and is not on this file's include path. Values are unchanged.
 * --------------------------------------------------------------------------- */
#include <helper_xyz_parser.h>

/* This is a function that returns hardcoded XYZ coordinates of a
 * water molecule in a parsedXYZFile_t structure.
 */
static parsedXYZFile_t* h2oXYZFile()
{
    size_t numAtoms = 3;
    double* xyzCPU = (double*) malloc(3 * numAtoms * sizeof(double));
    double* chargesCPU = (double*) malloc(numAtoms * sizeof(double));
    char **symbols = (char**) malloc(numAtoms * sizeof(char*));
    if (!xyzCPU || !chargesCPU || !symbols) {
        if (xyzCPU) free(xyzCPU);
        if (chargesCPU) free(chargesCPU);
        if (symbols) free(symbols);
        fprintf(stderr, "Failed to allocate host memory\n");
        exit(EXIT_FAILURE);
    }

    chargesCPU[0] = -8.0;
    chargesCPU[1] = -1.0;
    chargesCPU[2] = -1.0;

    xyzCPU[0*3 + 0] =  0.000000;
    xyzCPU[0*3 + 1] = -0.224906;
    xyzCPU[0*3 + 2] =  0.000000;

    xyzCPU[1*3 + 0] =  1.452350;
    xyzCPU[1*3 + 1] =  0.899624;
    xyzCPU[1*3 + 2] =  0.000000;

    xyzCPU[2*3 + 0] = -1.452350;
    xyzCPU[2*3 + 1] =  0.899624;
    xyzCPU[2*3 + 2] =  0.000000;

    int fail = 0;
    const char *temp[] = {"O", "H", "H"};
    for (int i=0; i<numAtoms; i++) {
        symbols[i] = malloc(strlen(temp[i]) + 1);
        if (!symbols[i]) {
            fail = 1;
            break;
        }
        strcpy(symbols[i], temp[i]);
    }

    if (fail) {
        free(xyzCPU);
        free(chargesCPU);
        for (size_t i=0; i<numAtoms; i++) {
            if (symbols[i]) {
                free(symbols[i]);
            }
        }
        free(symbols);
        fprintf(stderr, "Failed to allocate atomic symbols\n");
        exit(EXIT_FAILURE);
    }

    double* xyzGPU = NULL;
    double* chargesGPU = NULL;
    parsedXYZFile_t* result = NULL;

    do {
        if (cudaMalloc((void**) &xyzGPU, 3 * numAtoms * sizeof(double)) != cudaSuccess) {
            fail = 1;
            break;
        }
        if (cudaMalloc((void**) &chargesGPU, numAtoms * sizeof(double)) != cudaSuccess) {
            fail = 1;
            break;
        }
        if (cudaMemcpy(xyzGPU, xyzCPU, 3 * numAtoms * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) {
            fail = 1;
            break;
        }
        if (cudaMemcpy(chargesGPU, chargesCPU,  numAtoms * sizeof(double), cudaMemcpyHostToDevice) != cudaSuccess) {
            fail = 1;
            break;
        }
    }
    while(0);

    result = (parsedXYZFile_t*) malloc(sizeof(parsedXYZFile_t));
    if (!result || fail) {
        if (result) free(result);
        if (xyzGPU) cudaFree(xyzGPU);
        if (chargesGPU) cudaFree(chargesGPU);
        free(xyzCPU);
        free(chargesCPU);
        for (size_t i=0; i<numAtoms; i++) {
            if (symbols[i]) {
                free(symbols[i]);
            }
        }
        free(symbols);
        fprintf(stderr, "Memory allocation/copy failed\n");
        exit(EXIT_FAILURE);
    }

    result->numAtoms = numAtoms;
    result->xyzCPU = xyzCPU;
    result->xyzGPU = xyzGPU;
    result->chargesCPU = chargesCPU;
    result->chargesGPU = chargesGPU;
    result->symbols = symbols;

    return result;
}
/* ------------------------- end of inlined header -------------------------- */

/*
 * This example shows how to construct a pruned integration grid 
 * following:
 *
 * Reference: O. Treutler and R. Ahlrichs,
 *   J. Chem. Phys., 102, 346 (1995)
 *
 * This example builds "GRID1" for a water molecule. 
 */

/*
 * This function produces the Ahlrichs radial quadrature. It takes
 * preallocated arrays to store the radial nodes and weights as input
 * and populates them with the quadrature. Arrays must be of length
 * npoint.
 */
void build_ahlrichs_radial_quadrature(
    size_t npoint,
    double R,
    double *radialNodes,
    double *radialWeights)
{
    const double alpha = 0.6;
    for (size_t i = 1; i <= npoint; i++) {
        double z = i * M_PI / (npoint + 1.0);
        double x = cos(z);
        double y = sin(z);
        double u = log((1.0 - x) / 2.0);
        double v = pow(1.0 + x, alpha) / log(2.0);
        double r = - R * v * u;
        double w = M_PI / (npoint + 1.0) * y * R  * v * (-alpha * u / (1.0 + x) + 1.0 / (1.0 - x)) * r * r;
        radialNodes[npoint-i] = r;
        radialWeights[npoint-i] = w;
    }
}

int main(int argc, char **argv)
{
    /* Obtain XYZ coordinates of a water molecule. */
    parsedXYZFile_t* xyzData = h2oXYZFile();
    if (!xyzData) {
        fprintf(stderr, "Error: failed to produce H2O xyz data\n");
        exit(EXIT_FAILURE);
    }

    /**********************/
    /* cuEST Handle Setup */
    /**********************/

    /* Create the cuEST handle. */
    cuestHandle_t handle;
    cuestHandleParameters_t handle_parameters;
    checkCuestErrors(cuestParametersCreate(
        CUEST_HANDLE_PARAMETERS, 
        &handle_parameters));
    checkCuestErrors(cuestCreate(
        handle_parameters, 
        &handle));
    checkCuestErrors(cuestParametersDestroy(
        CUEST_HANDLE_PARAMETERS, 
        handle_parameters));

    /***************************/
    /* cuEST Atomic Grid Setup */
    /***************************/

    /* Build an array of cuestAtomGrid_t for each atom in the molecule. */
    uint64_t numAtoms = xyzData->numAtoms;
    cuestAtomGrid_t* atomGrid = (cuestAtomGrid_t*) malloc(numAtoms * sizeof(cuestAtomGrid_t));
    if (!atomGrid) {
        checkCuestErrors(cuestDestroy(handle));
        freeParsedXYZFile(xyzData);
        fprintf(stderr, "Failed to allocate memory\n");
        exit(EXIT_FAILURE);
    }
    
    for (uint64_t n=0; n<numAtoms; n++) {

        /* Define the number of radial points and atomic radius for each atom. */
        size_t numRadialPoints = 0;
        double radius = 0.0;
        if (strcmp("O", xyzData->symbols[n]) == 0) {
            numRadialPoints = 25;
            radius = 0.90;
        }
        else /* (strcmp("H", xyzData->symbols[n]) == 0) */ {
            numRadialPoints = 20;
            radius = 0.80;
        }

        /* Allocate space for the radial and angular quadratures. */
        double *radialNodes = NULL;
        double *radialWeights = NULL;
        uint64_t *numAngularPointsArray = NULL;
 
        int fail = 0;
        do {
            radialNodes = (double*) malloc(numRadialPoints * sizeof(double));
            if (!radialNodes) {
                fail = 1;
                break;
            }
            radialWeights = (double*) malloc(numRadialPoints * sizeof(double));
            if (!radialWeights) {
                fail = 1;
                break;
            }
            numAngularPointsArray = (uint64_t*) malloc(numRadialPoints * sizeof(uint64_t));
            if (!numAngularPointsArray) {
                fail = 1;
                break;
            }
        }
        while(0);
      
        if (fail) {
            free(radialNodes);
            free(radialWeights);
            free(numAngularPointsArray);
            break;
        }

        /* The Treutler-Ahlrichs pruning scheme is encoded in the array of angular points. */
        if (strcmp("O", xyzData->symbols[n]) == 0) {
            for (uint64_t i=0; i<8; i++) {
                numAngularPointsArray[i] = 14;
            }
            for (uint64_t i=8; i<12; i++) {
                numAngularPointsArray[i] = 50;
            }
            for (uint64_t i=12; i<numRadialPoints; i++) {
                numAngularPointsArray[i] = 110;
            }
        }
        else /* (strcmp("H", xyzData->symbols[n]) == 0) */ {
            for (uint64_t i=0; i<6; i++) {
                numAngularPointsArray[i] = 14;
            }
            for (uint64_t i=6; i<10; i++) {
                numAngularPointsArray[i] = 50;
            }
            for (uint64_t i=10; i<numRadialPoints; i++) {
                numAngularPointsArray[i] = 50;
            }
        }

        /* Create the cuestAtomGrid_t for each atom. */
        cuestAtomGridParameters_t atomGridParameters;
        checkCuestErrors(cuestParametersCreate(
            CUEST_ATOMGRID_PARAMETERS, 
            &atomGridParameters));
        build_ahlrichs_radial_quadrature(
            numRadialPoints,
            radius,
            radialNodes,
            radialWeights);
        checkCuestErrors(cuestAtomGridCreate(
            handle,
            numRadialPoints,
            radialNodes,
            radialWeights,
            numAngularPointsArray,
            atomGridParameters,
            &atomGrid[n]));
        checkCuestErrors(cuestParametersDestroy(
            CUEST_ATOMGRID_PARAMETERS,
            atomGridParameters));

        /* ADDED: report the quadrature before the buffers go away. */
        {
            char label[64];
            double *repAngular = (double*) malloc(numRadialPoints * sizeof(double));
            if (!repAngular) {
                fprintf(stderr, "Failed to allocate memory\n");
                exit(EXIT_FAILURE);
            }
            for (size_t i = 0; i < numRadialPoints; i++) {
                repAngular[i] = (double) numAngularPointsArray[i];
            }
            snprintf(label, sizeof(label), "atom %llu radial nodes",
                     (unsigned long long) (n + 1));
            oracle_report_array(label, radialNodes, numRadialPoints);
            snprintf(label, sizeof(label), "atom %llu radial weights",
                     (unsigned long long) (n + 1));
            oracle_report_array(label, radialWeights, numRadialPoints);
            snprintf(label, sizeof(label), "atom %llu num angular points",
                     (unsigned long long) (n + 1));
            oracle_report_array(label, repAngular, numRadialPoints);
            free(repAngular);
        }

        /* Free temporary arrays. */
        free(radialNodes);
        free(radialWeights);
        free(numAngularPointsArray);
    }

    /******************************/
    /* cuEST Molecular Grid Setup */
    /******************************/

    /* Declare the molecular grid handle. */
    cuestMolecularGrid_t molecularGrid;

    /* Declare and create the molecular grid parameter handle. */
    cuestMolecularGridParameters_t molecularGridParameters;
    checkCuestErrors(cuestParametersCreate(
        CUEST_MOLECULARGRID_PARAMETERS, 
        &molecularGridParameters));

    /* Allocate space for workspace descriptors. Will be used to determine how large the workspace needs to be. */
    cuestWorkspaceDescriptor_t* persistentWorkspaceDescriptor = (cuestWorkspaceDescriptor_t*) malloc(sizeof(cuestWorkspaceDescriptor_t));
    cuestWorkspaceDescriptor_t* temporaryWorkspaceDescriptor = (cuestWorkspaceDescriptor_t*) malloc(sizeof(cuestWorkspaceDescriptor_t));

    /* Determine the workspaces required to construct the molecular grid. */
    checkCuestErrors(cuestMolecularGridCreateWorkspaceQuery(
        handle,
        xyzData->numAtoms,
        atomGrid,
        xyzData->xyzCPU,   
        molecularGridParameters,
        persistentWorkspaceDescriptor,
        temporaryWorkspaceDescriptor,
        &molecularGrid));
    
    /* Allocate buffers for the temporary and persistent workspaces. */
    cuestWorkspace_t* persistentGridWorkspace = allocateWorkspace(persistentWorkspaceDescriptor);;
    cuestWorkspace_t* temporaryGridWorkspace = allocateWorkspace(temporaryWorkspaceDescriptor);;

    /* Create the molecular grid. */
    checkCuestErrors(cuestMolecularGridCreate(
        handle,
        xyzData->numAtoms,
        atomGrid,
        xyzData->xyzCPU,   
        molecularGridParameters,
        persistentGridWorkspace,
        temporaryGridWorkspace,
        &molecularGrid));

    /* The molecular grid parameter handle is no longer needed. */
    checkCuestErrors(cuestParametersDestroy(
        CUEST_MOLECULARGRID_PARAMETERS,
        molecularGridParameters));

    /* The temporary workspace can be freed. */
    freeWorkspace(temporaryGridWorkspace);

    /* ADDED: query the finished grids for their documented attributes and
     * report them, with the same labels the Fortran port uses. */
    {
        char label[64];
        uint64_t v = 0;
        for (uint64_t n = 0; n < numAtoms; n++) {
            checkCuestErrors(cuestQuery(handle, CUEST_ATOMGRID, atomGrid[n],
                CUEST_ATOMGRID_NUM_POINT, &v, sizeof(uint64_t)));
            snprintf(label, sizeof(label), "atom %llu grid num_point",
                     (unsigned long long) (n + 1));
            oracle_report_scalar(label, (double) v);
            checkCuestErrors(cuestQuery(handle, CUEST_ATOMGRID, atomGrid[n],
                CUEST_ATOMGRID_NUM_RADIAL_POINT, &v, sizeof(uint64_t)));
            snprintf(label, sizeof(label), "atom %llu grid num_radial_point",
                     (unsigned long long) (n + 1));
            oracle_report_scalar(label, (double) v);
            checkCuestErrors(cuestQuery(handle, CUEST_ATOMGRID, atomGrid[n],
                CUEST_ATOMGRID_MAX_ANGULAR_POINT, &v, sizeof(uint64_t)));
            snprintf(label, sizeof(label), "atom %llu grid max_angular_point",
                     (unsigned long long) (n + 1));
            oracle_report_scalar(label, (double) v);
        }

        checkCuestErrors(cuestQuery(handle, CUEST_MOLECULARGRID, molecularGrid,
            CUEST_MOLECULARGRID_NUM_ATOM, &v, sizeof(uint64_t)));
        oracle_report_scalar("molecular grid num_atom", (double) v);
        checkCuestErrors(cuestQuery(handle, CUEST_MOLECULARGRID, molecularGrid,
            CUEST_MOLECULARGRID_NUM_POINT, &v, sizeof(uint64_t)));
        oracle_report_scalar("molecular grid num_point", (double) v);
        checkCuestErrors(cuestQuery(handle, CUEST_MOLECULARGRID, molecularGrid,
            CUEST_MOLECULARGRID_MAX_POINT, &v, sizeof(uint64_t)));
        oracle_report_scalar("molecular grid max_point", (double) v);
        checkCuestErrors(cuestQuery(handle, CUEST_MOLECULARGRID, molecularGrid,
            CUEST_MOLECULARGRID_NUM_RADIAL_POINT, &v, sizeof(uint64_t)));
        oracle_report_scalar("molecular grid num_radial_point", (double) v);
        checkCuestErrors(cuestQuery(handle, CUEST_MOLECULARGRID, molecularGrid,
            CUEST_MOLECULARGRID_MAX_RADIAL_POINT, &v, sizeof(uint64_t)));
        oracle_report_scalar("molecular grid max_radial_point", (double) v);
        checkCuestErrors(cuestQuery(handle, CUEST_MOLECULARGRID, molecularGrid,
            CUEST_MOLECULARGRID_MAX_ANGULAR_POINT, &v, sizeof(uint64_t)));
        oracle_report_scalar("molecular grid max_angular_point", (double) v);
    }

    /* The workspace descriptors are no longer needed. */
    free(persistentWorkspaceDescriptor);
    free(temporaryWorkspaceDescriptor);

    /*****************************************/
    /* Destroy cuEST handles and free memory */
    /*****************************************/

    /* Destroy the molecular grid handle. */
    checkCuestErrors(cuestMolecularGridDestroy(molecularGrid));
    freeWorkspace(persistentGridWorkspace);

    /* Destroy the atom grid handles. */
    for (int n=0; n<xyzData->numAtoms; n++) {
        checkCuestErrors(cuestAtomGridDestroy(atomGrid[n]));
    }
    free(atomGrid);

    /* Destroy the cuEST handle. */
    checkCuestErrors(cuestDestroy(handle));

    /* Free the XYZ data */
    freeParsedXYZFile(xyzData);

    return 0;
}
