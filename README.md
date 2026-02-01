Secure Flip-Flop Designs – Vivado Project

This repository contains several flip-flop designs and corresponding Vivado projects focusing on full and selective security mechanisms in hardware design. The project also includes simulations, testbenches, and supporting documentation.
it takes the implementation of dilithium and uses the flipflops majority voter design to ensure security against fault injection 

Project Structure
flipflops/

    Contains:

        Flip-flop implementations

        Corresponding testbenches for verification

fully_secure/ ( I have not pushed this yet, this is still running locally)

    Vivado project for the fully secured design

    every single flipflop is secured in this version

selective_security/

    Vivado project for the selectively secured design

    Only specific registers or states are protected

TEXTE/

    Collection of all notes, important information, and design explanations

    Serves as the main documentation and reference folder

Verilog Source Files

    fully_secure.v:
    Verilog implementation of the fully secured version

partly_secure_selective_trm.v:
    Verilog implementation of the selective security design,
    where only the final-state registers are protected

partly_secure.v:
    Vivado-generated reference design
    (exported using write_verilog)
    The file name will be changed to improve clarity and project overview. but I just let it as it is for the time being 

*Current Status:*

    A simulation of fully_secure.v is currently running locally

    Additional simulations and evaluations are planned

*Notes*

    The project structure is still evolving

    File and folder names may be adjusted for better clarity

    All relevant background information can be found in the TEXTE folder