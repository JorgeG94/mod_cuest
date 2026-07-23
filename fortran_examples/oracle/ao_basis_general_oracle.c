/*
 * Derived from NVIDIA's cuEST C sample
 *   c_examples/examples/1_basic_data_structures/ao_basis_general/main.c
 * (Apache-2.0, Copyright (c) NVIDIA CORPORATION & AFFILIATES).
 *
 * MODIFIED: the workspace sizes are copied out of the descriptors before those
 * are freed, and every number the sample prints is additionally reported with
 * oracle_report_scalar() after all of the sample's own output, so it can be
 * compared numerically against the Fortran port. Reporting after the printf
 * output matters: compare.py would otherwise read lines such as
 * "Persistent CPU Workspace: 1234" as fields of the preceding report section.
 * Nothing else is changed -- the setup path is byte-identical to upstream,
 * which is the point: it is the reference, not a reimplementation.
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
#include <helper_gbs_parser.h>
#include <helper_ao_shells.h>

/* ADDED: shared reporting, so this oracle and the Fortran port
 * print the identical format that compare.py parses. */
#include "oracle_report.h"

/*
 * This sample shows how to construct an AO basis handle for an arbitrary
 * molecule and arbitrary basis set. This uses some of the helper functions
 * in the common directory to parse XYZ and GBS files.
 *
 * Formatting for XYZ files should be:
 *
 * [Number of atoms]
 * Comment line
 * Symbol_1 X_1 Y_1 Z_1
 * Symbol_2 X_2 Y_2 Z_2
 * ...
 * ...
 * Symbol_N X_N Y_N Z_N
 *
 * The units used in the XYZ files can be handled through the 
 * toBohrScaleFactor argument to parseXYZFile. In this sample,
 * it is assumed the xyz coordinates are given in angrstoms.
 *
 * The GBS files use the Gaussian94 formatting for the basis set.
 * Comment lines are skipped (those that start with !). The use
 * of SP or SPD shells in the definition is not supported -- that
 * is, specifying S and P shells that use the same exponents, 
 * simultaneously. 
 *
 * If basis sets are obtained from the EMSL basis set exchange,
 * download the files in "Gaussian" format and select
 * "Uncontract SPDF". Alternatively, files can be downloaded in
 * "Psi4" format. ECPs may be included in the GBS file, but will
 * not be parsed.
 */
int main(int argc, char **argv)
{
    /* Check that an xyz file has been provided */
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <xyz_file_path> <gbs_file_path>\n", argv[0]);
        exit(EXIT_FAILURE);
    }
    const char* xyzFilePath = argv[1];
    const char* gbsFilePath = argv[2];

    /* Parse the XYZ file */
    parsedXYZFile_t* xyzData = parseXYZFile(xyzFilePath, 1.0 / 0.52917720859);
    if (!xyzData) {
        fprintf(stderr, "Error: failed to parse file '%s'\n", xyzFilePath);
        exit(EXIT_FAILURE);
    }

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

    /* Use the AO shell helper to build the array of AO shells */
    AtomShellData_t* shell_data = formAOShells(handle, xyzData, gbsFilePath, 1);

    /* Unpack the AtomShellData_t struct */
    uint64_t numAtoms = shell_data->numAtoms;
    uint64_t numShellsTotal = shell_data->numShellsTotal;
    uint64_t* numShellsPerAtom = shell_data->numShellsPerAtom;
    cuestAOShell_t* shells = shell_data->shells;

    /* Free the XYZ data */
    freeParsedXYZFile(xyzData);

    /* Declare the AO basis handle. */
    cuestAOBasis_t basis;

    /* Declare the AO basis parameter handle. */
    cuestAOBasisParameters_t basis_parameters;
    checkCuestErrors(cuestParametersCreate(CUEST_AOBASIS_PARAMETERS, &basis_parameters));

    /* Allocate space for workspace descriptors. Will be used to determine how large the workspace needs to be. */
    cuestWorkspaceDescriptor_t* persistentWorkspaceDescriptor = (cuestWorkspaceDescriptor_t*) malloc(sizeof(cuestWorkspaceDescriptor_t));
    cuestWorkspaceDescriptor_t* temporaryWorkspaceDescriptor = (cuestWorkspaceDescriptor_t*) malloc(sizeof(cuestWorkspaceDescriptor_t));

    /* Make the workspace query to populate the workspace descriptors. */
    checkCuestErrors(cuestAOBasisCreateWorkspaceQuery(
        handle, 
        numAtoms, 
        numShellsPerAtom, 
        (const cuestAOShell_t*) shells, 
        basis_parameters, 
        persistentWorkspaceDescriptor, 
        temporaryWorkspaceDescriptor, 
        &basis));

    printf("AO Basis Workspace Descriptors\n");
    printf("Persistent CPU Workspace: %zu\n", persistentWorkspaceDescriptor->hostBufferSizeInBytes);
    printf("Persistent GPU Workspace: %zu\n", persistentWorkspaceDescriptor->deviceBufferSizeInBytes);
    printf("Temporary CPU Workspace:  %zu\n", temporaryWorkspaceDescriptor->hostBufferSizeInBytes);
    printf("Temporary GPU Workspace:  %zu\n", temporaryWorkspaceDescriptor->deviceBufferSizeInBytes);
    printf("\n");

    /* ADDED: the descriptors are freed a few lines below, so keep the sizes. */
    double rep_ws[4] = {
        (double) persistentWorkspaceDescriptor->hostBufferSizeInBytes,
        (double) persistentWorkspaceDescriptor->deviceBufferSizeInBytes,
        (double) temporaryWorkspaceDescriptor->hostBufferSizeInBytes,
        (double) temporaryWorkspaceDescriptor->deviceBufferSizeInBytes
    };

    /* Allocate buffers for the temporary and persistent workspaces. */
    cuestWorkspace_t* persistentWorkspace = allocateWorkspace(persistentWorkspaceDescriptor);;
    cuestWorkspace_t* temporaryWorkspace = allocateWorkspace(temporaryWorkspaceDescriptor);;

    /* The workspace descriptors are no longer needed. */
    free(persistentWorkspaceDescriptor);
    free(temporaryWorkspaceDescriptor);

    /* Create the AO basis handle. */
    checkCuestErrors(cuestAOBasisCreate(
        handle, 
        numAtoms, 
        numShellsPerAtom, 
        (const cuestAOShell_t*) shells, 
        basis_parameters, 
        persistentWorkspace, 
        temporaryWorkspace, 
        &basis));

    /* The temporary workspace is no longer needed. */
    freeWorkspace(temporaryWorkspace);

    /* The AO basis parameters are no longer needed. */
    checkCuestErrors(cuestParametersDestroy(
        CUEST_AOBASIS_PARAMETERS, 
        basis_parameters));

    /* Free all the shell data */
    freeAOShellData(shell_data);

    /*
     * From here, the AO basis handle and the persistentWorkspace must be retined
     * in order the use the handle. The shells, shell parameters, workspace
     * descriptors are no longer needed and have already been freed.
     */

    /* 
     * Query the AO basis handle to determine the size of the basis. If it was
     * constructed correctly, the sizes will match those calculated from the 
     * array of shells.
     */
    uint64_t natom = 0;
    uint64_t max_L = 0;
    uint64_t nshell = 0;
    uint64_t nao = 0;
    uint64_t ncart = 0;
    uint64_t nprimitive = 0;
    int32_t is_pure = 0;

    checkCuestErrors(cuestQuery(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_NUM_ATOM,      &natom,      sizeof(uint64_t)));
    checkCuestErrors(cuestQuery(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_NUM_SHELL,     &nshell,     sizeof(uint64_t)));
    checkCuestErrors(cuestQuery(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_NUM_AO,        &nao,        sizeof(uint64_t)));
    checkCuestErrors(cuestQuery(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_NUM_CART,      &ncart,      sizeof(uint64_t)));
    checkCuestErrors(cuestQuery(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_NUM_PRIMITIVE, &nprimitive, sizeof(uint64_t)));
    checkCuestErrors(cuestQuery(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_MAX_L,         &max_L,      sizeof(uint64_t)));
    checkCuestErrors(cuestQuery(handle, CUEST_AOBASIS, basis, CUEST_AOBASIS_IS_PURE,       &is_pure,    sizeof(int32_t)));

    fprintf(stdout,"AO Basis from handle:\n");
    fprintf(stdout,"%-10s = %6zu\n", "natom",      natom);
    fprintf(stdout,"%-10s = %6zu\n", "nshell",     nshell);
    fprintf(stdout,"%-10s = %6zu\n", "nao",        nao);
    fprintf(stdout,"%-10s = %6zu\n", "ncart",      ncart);
    fprintf(stdout,"%-10s = %6zu\n", "nprimitive", nprimitive);
    fprintf(stdout,"%-10s = %6zu\n", "max_L",      max_L);
    fprintf(stdout,"%-10s = %6s\n",  "is_pure",    is_pure ? "true" : "false");

    /* ADDED: report every queried quantity, after all of the sample's own
     * output, with the same labels the Fortran port uses. */
    oracle_report_scalar("workspace persistent host bytes",   rep_ws[0]);
    oracle_report_scalar("workspace persistent device bytes", rep_ws[1]);
    oracle_report_scalar("workspace temporary host bytes",    rep_ws[2]);
    oracle_report_scalar("workspace temporary device bytes",  rep_ws[3]);

    oracle_report_scalar("basis natom",      (double) natom);
    oracle_report_scalar("basis nshell",     (double) nshell);
    oracle_report_scalar("basis nao",        (double) nao);
    oracle_report_scalar("basis ncart",      (double) ncart);
    oracle_report_scalar("basis nprimitive", (double) nprimitive);
    oracle_report_scalar("basis max_L",      (double) max_L);
    oracle_report_scalar("basis is_pure",    (double) is_pure);

    /* Destroy the AO basis handle. */
    checkCuestErrors(cuestAOBasisDestroy(basis));
    freeWorkspace(persistentWorkspace);

    /* Destroy the cuEST handle. */
    checkCuestErrors(cuestDestroy(handle));

    return 0;
}
