# Runs the C reference and the Fortran port on the same input, then compares
# them numerically. Invoked by CTest; not meant to be run directly.
execute_process(COMMAND ${RUNNER} ${WORKDIR} ${C_EXE} ${NAME}
                OUTPUT_FILE ${WORKDIR}/${NAME}.c.out RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "C reference for ${NAME} failed (exit ${rc})")
endif()
execute_process(COMMAND ${RUNNER} ${WORKDIR} ${FORTRAN_EXE} ${NAME}
                OUTPUT_FILE ${WORKDIR}/${NAME}.f.out RESULT_VARIABLE rf)
if(NOT rf EQUAL 0)
    message(FATAL_ERROR "Fortran port ${NAME} failed (exit ${rf})")
endif()
execute_process(COMMAND ${COMPARE}
                ${WORKDIR}/${NAME}.c.out ${WORKDIR}/${NAME}.f.out
                RESULT_VARIABLE rcmp)
if(NOT rcmp EQUAL 0)
    message(FATAL_ERROR "${NAME}: comparison failed")
endif()
