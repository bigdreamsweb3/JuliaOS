using Libdl

const RUST_SIGNER_LIB_NAME_ONLY = "rust_juliaos_signer"
const RELATIVE_LIB_PATH = joinpath("packages", "rust_signer", "target", "debug", "lib" * RUST_SIGNER_LIB_NAME_ONLY * "." * Libdl.dlext)
# Global constant for ccall, as required by Julia - will be used if dlopen_e by name works
const CCALL_LIB_NAME_REFERENCE = "lib" * RUST_SIGNER_LIB_NAME_ONLY

function test_library_open()
    lib_handle = C_NULL
    opened_successfully = false
    try
        println("Attempting to open library using relative path: $(abspath(RELATIVE_LIB_PATH))")
        if isfile(RELATIVE_LIB_PATH)
            lib_handle = Libdl.dlopen_e(RELATIVE_LIB_PATH)
            if lib_handle != C_NULL
                println("SUCCESS: Opened library with relative path.")
                opened_successfully = true
            else
                println("ERROR: Failed to open with relative path, though file exists.")
            end
        else
            println("WARNING: Library not found at expected relative path: $(abspath(RELATIVE_LIB_PATH))")
            println("Attempting to open library using name only: $( "lib" * RUST_SIGNER_LIB_NAME_ONLY )")
            lib_handle = Libdl.dlopen_e("lib" * RUST_SIGNER_LIB_NAME_ONLY)
            if lib_handle != C_NULL
                println("SUCCESS: Opened library with name only.")
                opened_successfully = true
            else
                println("ERROR: Failed to open with name only.")
            end
        end

        if !opened_successfully
             println("ERROR: Julia could not open the Rust library via path or name.")
             return false
        end
        
        # Minimal test: just try calling a function that might not exist to see if dlopen worked.
        # Or, if we had a simple function in Rust like `int test_func() { return 123; }`
        # We could try to call it. For now, just opening is the test.
        # If `rust_lib_health_check` is present, let's try it.
        if opened_successfully
            println("Attempting to call 'rust_lib_health_check'...")
            try
                result_code = -1 # Default error
                # We need to determine if dlopen_e succeeded with RELATIVE_LIB_PATH or CCALL_LIB_NAME_REFERENCE
                # The variable `lib_path_to_try` is not available here.
                # However, if lib_handle is valid, dlopen_e succeeded.
                # The most robust way is to use the handle directly in ccall.
                if lib_handle != C_NULL
                    println("Using library handle and dlsym for ccall.")
                    func_ptr = Libdl.dlsym(lib_handle, :rust_lib_health_check)
                    if func_ptr == C_NULL
                        println("ERROR: Could not find symbol :rust_lib_health_check in the library.")
                        opened_successfully = false
                    else
                        result_code = ccall(func_ptr, Cint, ())
                    end
                else
                    # This case should ideally not be reached if opened_successfully is true.
                    # If dlopen_e failed, opened_successfully would be false.
                    # If somehow opened_successfully is true but handle is C_NULL, this is an issue.
                    # For safety, we could try ccall with the name, but it likely failed dlopen_e too.
                    println("ERROR: lib_handle is C_NULL, cannot proceed with ccall reliably.")
                    opened_successfully = false # Mark as failure
                end

                if opened_successfully # Re-check because the above error path sets it to false
                    if result_code == 0
                        println("SUCCESS: Health check returned 0.")
                    else
                        println("WARNING: Health check called, but returned non-zero or failed: $result_code.")
                        opened_successfully = (result_code == 0) 
                    end
                end
            catch e
                println("ERROR calling health_check: $e")
                opened_successfully = false # Consider this a failure too
            end
        end
        return opened_successfully

    catch e_outer
        println("Outer catch block error: $e_outer")
        return false
    finally
        if lib_handle != C_NULL
            Libdl.dlclose(lib_handle)
            println("Closed library handle.")
        end
    end
end

if test_library_open()
    println("\nFFI Library Load Test: PASSED")
else
    println("\nFFI Library Load Test: FAILED")
end
