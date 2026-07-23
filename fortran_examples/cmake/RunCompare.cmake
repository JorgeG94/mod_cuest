# Runs the C reference and the Fortran port on the same input, then compares
# them numerically. Invoked by CTest; not meant to be run directly.
execute_process(COMMAND ${C_EXE} ${XYZ} ${GBS}
                OUTPUT_FILE ${WORKDIR}/c.out RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "C reference failed (exit ${rc})")
endif()
execute_process(COMMAND ${FORTRAN_EXE} ${XYZ} ${GBS}
                OUTPUT_FILE ${WORKDIR}/f.out RESULT_VARIABLE rf)
if(NOT rf EQUAL 0)
    message(FATAL_ERROR "Fortran port failed (exit ${rf})")
endif()
execute_process(COMMAND ${COMPARE} ${WORKDIR}/c.out ${WORKDIR}/f.out
                RESULT_VARIABLE rcmp)
if(NOT rcmp EQUAL 0)
    message(FATAL_ERROR "comparison failed")
endif()
