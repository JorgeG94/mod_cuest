# Runs the C reference and the Fortran port on the same input, then compares
# them numerically. Invoked by CTest; not meant to be run directly.
#
# Failure messages deliberately distinguish "this GPU cannot run cuEST at all"
# from "the port disagrees with the reference" -- they need completely
# different responses, and the raw exit code does not tell them apart.

function(run_side WHO EXE OUT)
    execute_process(COMMAND ${RUNNER} ${WORKDIR} ${EXE} ${NAME}
                    OUTPUT_FILE ${OUT} ERROR_FILE ${OUT}.err
                    RESULT_VARIABLE rc)
    if(NOT rc EQUAL 0)
        set(txt "")
        if(EXISTS ${OUT})
            file(READ ${OUT} txt)
        endif()
        set(errtxt "")
        if(EXISTS ${OUT}.err)
            file(READ ${OUT}.err errtxt)
        endif()
        string(APPEND txt "${errtxt}")
        if(txt MATCHES "UNSUPPORTED_ARCHITECTURE")
            message(FATAL_ERROR
                "${NAME}: this GPU cannot run cuEST.\n"
                "cuEST ships cubins for sm_80 and newer; the ${WHO} aborted at "
                "cuestCreate with CUEST_STATUS_UNSUPPORTED_ARCHITECTURE.\n"
                "This is NOT a port defect and NOT a comparison failure -- run "
                "on an A100 or H100 (Gadi: dgxa100 or gpuhopper).")
        endif()
        message(FATAL_ERROR "${NAME}: the ${WHO} exited ${rc}.\n${txt}")
    endif()
endfunction()

run_side("C reference" ${C_EXE} ${WORKDIR}/${NAME}.c.out)
run_side("Fortran port" ${FORTRAN_EXE} ${WORKDIR}/${NAME}.f.out)

# Invoked through the interpreter, not as ${COMPARE} directly: relying on the
# script's executable bit made every CTest comparison fail with "Permission
# denied" while run_all.sh -- which calls python3 explicitly -- passed. A file
# mode is not a good thing for the test suite to depend on.
execute_process(COMMAND ${PYTHON_EXE} ${COMPARE}
                ${WORKDIR}/${NAME}.c.out ${WORKDIR}/${NAME}.f.out
                OUTPUT_VARIABLE cmp_out ERROR_VARIABLE cmp_err
                RESULT_VARIABLE rcmp)
message("${cmp_out}")
if(NOT rcmp EQUAL 0)
    message(FATAL_ERROR
        "${NAME}: both binaries ran, but the Fortran port DISAGREES with the C "
        "reference.\n${cmp_out}${cmp_err}")
endif()
