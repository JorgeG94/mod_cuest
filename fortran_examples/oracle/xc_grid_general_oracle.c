/*
 * Derived from NVIDIA's cuEST C sample
 *   c_examples/examples/1_basic_data_structures/xc_grid_general/main.c
 * (Apache-2.0, Copyright (c) NVIDIA CORPORATION & AFFILIATES).
 *
 * MODIFIED: the sample builds the grid and exits without printing anything, so
 * the molecular-grid workspace sizes and the documented attributes of the
 * finished atom grids and molecular grid are reported with
 * oracle_report_scalar(), giving the Fortran port something to be compared
 * against. Nothing else is changed -- the setup path is byte-identical to
 * upstream, which is the point: it is the reference, not a reimplementation.
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

#include <cuest.h>

#include <helper_status.h>
#include <helper_workspaces.h>
#include <helper_xyz_parser.h>
#include <helper_grid.h>

/* ADDED: shared reporting, so this oracle and the Fortran port
 * print the identical format that compare.py parses. */
#include "oracle_report.h"

/*
 * This example shows how to construct a basic integration grid for a
 * molecule. It uses the grid helper to produce an unpruned grid with
 * a number of radial and angular points determined by the user
 * (here, 75 radial, 302 angular). This molecular grid handle forms
 * the basis of exchange-correlation evaluation in cuEST.
 */

int main(int argc, char **argv)
{
    /* Check that an xyz file has been provided */
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <xyz_file_path>\n", argv[0]);
        exit(EXIT_FAILURE);
    }
    const char* xyzFilePath = argv[1];

    /* Parse the XYZ file */
    parsedXYZFile_t* xyzData = parseXYZFile(xyzFilePath, 1.0 / 0.52917720859);
    if (!xyzData) {
        fprintf(stderr, "Error: failed to parse file '%s'\n", xyzFilePath);
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

    /* This forms an unpruned (75, 302) grid with Ahlrichs radial quadrature. */
    cuestAtomGrid_t* atomGrid = formDirectProductAtomGrid(
        handle,
        xyzData,
        75,
        302);

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

    /* ADDED: the descriptors are freed further down, so keep the sizes. */
    double rep_ws[4] = {
        (double) persistentWorkspaceDescriptor->hostBufferSizeInBytes,
        (double) persistentWorkspaceDescriptor->deviceBufferSizeInBytes,
        (double) temporaryWorkspaceDescriptor->hostBufferSizeInBytes,
        (double) temporaryWorkspaceDescriptor->deviceBufferSizeInBytes
    };

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

    /* ADDED: report the workspace sizes and query the finished grids for their
     * documented attributes, with the same labels the Fortran port uses. */
    {
        char label[64];
        uint64_t v = 0;

        oracle_report_scalar("num atoms", (double) xyzData->numAtoms);
        oracle_report_scalar("workspace persistent host bytes",   rep_ws[0]);
        oracle_report_scalar("workspace persistent device bytes", rep_ws[1]);
        oracle_report_scalar("workspace temporary host bytes",    rep_ws[2]);
        oracle_report_scalar("workspace temporary device bytes",  rep_ws[3]);

        for (uint64_t n = 0; n < xyzData->numAtoms; n++) {
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

    /*****************************************/
    /* Destroy cuEST handles and free memory */
    /*****************************************/

    /* The workspace descriptors are no longer needed. */
    free(persistentWorkspaceDescriptor);
    free(temporaryWorkspaceDescriptor);

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
