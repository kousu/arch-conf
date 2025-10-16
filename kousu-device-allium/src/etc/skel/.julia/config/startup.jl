if isinteractive()
try
    using Revise
catch e
    @warn "Error initializing Revise" exception=(e, catch_backtrace())
end
end

# automatically activate the environment of the current project, if it exists
# (it's okay to have, but they will be working in the default)
# (alternately use `julia --project="@."`)
if isfile("Project.toml")
    try
        using Pkg; Pkg.activate(".")
        #println("Activated project: ", Base.current_project())
    catch e
        @warn "Failed to auto-activate project" exception=(e, catch_backtrace())
    end
end

if startswith(abspath(pwd()), "/home/kousu/School")
    try
	push!(LOAD_PATH, expanduser("~/.julia/environments/school"))
	#using Plots  # this is fucked up somehow. it's initialising _too soon_ and not routing to a proper graphics backend
	using LaTeXStrings
    catch e
        @warn "Failed to auto-load school tools" exception=(e, catch_backtrace())
    end
end

