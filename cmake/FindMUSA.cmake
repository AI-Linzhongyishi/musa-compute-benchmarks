# FindMUSA.cmake - Modern CMake module for Moore Threads MUSA Toolkit
# Provides MUSA toolchain detection, include paths, libraries, and compilation macros

find_path(MUSA_INCLUDE_DIR
    NAMES musa_runtime.h musa_surface_types.h
    PATHS
        ENV MUSA_PATH
        /usr/local/musa/include
        /home/linzhongyishi/musa_sdk/installed/MUSA_Toolkits_4.3.0/musa_toolkits_4.3.0/include
    PATH_SUFFIXES include
)

find_library(MUSA_RUNTIME_LIBRARY
    NAMES musart libmusart.so.4 libmusart.so
    PATHS
        ENV MUSA_PATH
        /usr/local/musa/lib
        /usr/local/musa/lib64
    PATH_SUFFIXES lib lib64
)

find_library(MUSA_DRIVER_LIBRARY
    NAMES musa libmusa.so.4 libmusa.so
    PATHS
        ENV MUSA_PATH
        /usr/local/musa/lib
        /usr/local/musa/lib64
        /usr/lib/x86_64-linux-gnu
    PATH_SUFFIXES lib lib64
)

find_program(MUSA_MCC_EXECUTABLE
    NAMES mcc
    PATHS
        ENV MUSA_PATH
        /usr/local/musa/bin
        /home/linzhongyishi/musa_sdk/installed/MUSA_Toolkits_4.3.0/musa_toolkits_4.3.0/bin
    PATH_SUFFIXES bin
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(MUSA
    REQUIRED_VARS MUSA_INCLUDE_DIR MUSA_RUNTIME_LIBRARY MUSA_MCC_EXECUTABLE
)

if(MUSA_FOUND)
    set(MUSA_INCLUDE_DIRS ${MUSA_INCLUDE_DIR})
    set(MUSA_LIBRARIES ${MUSA_RUNTIME_LIBRARY} ${MUSA_DRIVER_LIBRARY})
    get_filename_component(MUSA_LIB_DIR ${MUSA_RUNTIME_LIBRARY} DIRECTORY)
    
    # Macro to compile .mu files directly using mcc
    macro(musa_add_executable TARGET_NAME)
        set(SOURCES ${ARGN})
        set(OUTPUT_BIN ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME})
        set(COMPAT_FLAGS "-D__INTEL_LLVM_COMPILER=1" "-DSYCL_LANGUAGE_VERSION=202001" "-O3")
        
        add_custom_command(
            OUTPUT ${OUTPUT_BIN}
            COMMAND ${MUSA_MCC_EXECUTABLE} -I${MUSA_INCLUDE_DIR} -I${CMAKE_SOURCE_DIR}/benchmarks ${COMPAT_FLAGS} ${CMAKE_CURRENT_SOURCE_DIR}/${SOURCES} -o ${OUTPUT_BIN} -L${MUSA_LIB_DIR} -lmusart
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${SOURCES}
            COMMENT "[MUSA] Compiling ${TARGET_NAME} for Moore Threads MTT S80..."
        )
        add_custom_target(build_${TARGET_NAME} ALL DEPENDS ${OUTPUT_BIN})
    endmacro()
endif()
