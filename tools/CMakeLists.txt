# dependencies

find_package(Threads REQUIRED)

# third-party

# ...

# flags

llama_add_compile_flags()

# tools

if (EMSCRIPTEN)
else()
    if (LLAMA_BUILD_SERVER)
        add_subdirectory(ui)
        add_subdirectory(server)
        add_subdirectory(cli)
    endif()
    add_subdirectory(mtmd)
endif()
