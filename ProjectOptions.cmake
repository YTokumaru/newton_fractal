include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(newton_fractal_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(newton_fractal_setup_options)
  option(newton_fractal_ENABLE_HARDENING "Enable hardening" ON)
  option(newton_fractal_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    newton_fractal_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    newton_fractal_ENABLE_HARDENING
    OFF)

  newton_fractal_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR newton_fractal_PACKAGING_MAINTAINER_MODE)
    option(newton_fractal_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(newton_fractal_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(newton_fractal_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(newton_fractal_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(newton_fractal_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(newton_fractal_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(newton_fractal_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(newton_fractal_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(newton_fractal_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(newton_fractal_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(newton_fractal_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(newton_fractal_ENABLE_PCH "Enable precompiled headers" OFF)
    option(newton_fractal_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(newton_fractal_ENABLE_IPO "Enable IPO/LTO" ON)
    option(newton_fractal_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(newton_fractal_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(newton_fractal_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(newton_fractal_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(newton_fractal_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(newton_fractal_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(newton_fractal_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(newton_fractal_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(newton_fractal_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(newton_fractal_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(newton_fractal_ENABLE_PCH "Enable precompiled headers" OFF)
    option(newton_fractal_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      newton_fractal_ENABLE_IPO
      newton_fractal_WARNINGS_AS_ERRORS
      newton_fractal_ENABLE_USER_LINKER
      newton_fractal_ENABLE_SANITIZER_ADDRESS
      newton_fractal_ENABLE_SANITIZER_LEAK
      newton_fractal_ENABLE_SANITIZER_UNDEFINED
      newton_fractal_ENABLE_SANITIZER_THREAD
      newton_fractal_ENABLE_SANITIZER_MEMORY
      newton_fractal_ENABLE_UNITY_BUILD
      newton_fractal_ENABLE_CLANG_TIDY
      newton_fractal_ENABLE_CPPCHECK
      newton_fractal_ENABLE_COVERAGE
      newton_fractal_ENABLE_PCH
      newton_fractal_ENABLE_CACHE)
  endif()

  newton_fractal_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (newton_fractal_ENABLE_SANITIZER_ADDRESS OR newton_fractal_ENABLE_SANITIZER_THREAD OR newton_fractal_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(newton_fractal_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(newton_fractal_global_options)
  if(newton_fractal_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    newton_fractal_enable_ipo()
  endif()

  newton_fractal_supports_sanitizers()

  if(newton_fractal_ENABLE_HARDENING AND newton_fractal_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR newton_fractal_ENABLE_SANITIZER_UNDEFINED
       OR newton_fractal_ENABLE_SANITIZER_ADDRESS
       OR newton_fractal_ENABLE_SANITIZER_THREAD
       OR newton_fractal_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${newton_fractal_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${newton_fractal_ENABLE_SANITIZER_UNDEFINED}")
    newton_fractal_enable_hardening(newton_fractal_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(newton_fractal_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(newton_fractal_warnings INTERFACE)
  add_library(newton_fractal_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  newton_fractal_set_project_warnings(
    newton_fractal_warnings
    ${newton_fractal_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(newton_fractal_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(newton_fractal_options)
  endif()

  include(cmake/Sanitizers.cmake)
  newton_fractal_enable_sanitizers(
    newton_fractal_options
    ${newton_fractal_ENABLE_SANITIZER_ADDRESS}
    ${newton_fractal_ENABLE_SANITIZER_LEAK}
    ${newton_fractal_ENABLE_SANITIZER_UNDEFINED}
    ${newton_fractal_ENABLE_SANITIZER_THREAD}
    ${newton_fractal_ENABLE_SANITIZER_MEMORY})

  set_target_properties(newton_fractal_options PROPERTIES UNITY_BUILD ${newton_fractal_ENABLE_UNITY_BUILD})

  if(newton_fractal_ENABLE_PCH)
    target_precompile_headers(
      newton_fractal_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(newton_fractal_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    newton_fractal_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(newton_fractal_ENABLE_CLANG_TIDY)
    newton_fractal_enable_clang_tidy(newton_fractal_options ${newton_fractal_WARNINGS_AS_ERRORS})
  endif()

  if(newton_fractal_ENABLE_CPPCHECK)
    newton_fractal_enable_cppcheck(${newton_fractal_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(newton_fractal_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    newton_fractal_enable_coverage(newton_fractal_options)
  endif()

  if(newton_fractal_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(newton_fractal_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(newton_fractal_ENABLE_HARDENING AND NOT newton_fractal_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR newton_fractal_ENABLE_SANITIZER_UNDEFINED
       OR newton_fractal_ENABLE_SANITIZER_ADDRESS
       OR newton_fractal_ENABLE_SANITIZER_THREAD
       OR newton_fractal_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    newton_fractal_enable_hardening(newton_fractal_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
