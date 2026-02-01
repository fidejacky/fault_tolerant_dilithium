# Secure Flip-Flop Designs – Vivado Project

This repository contains multiple **flip-flop designs** and corresponding **Vivado projects** that investigate **full** and **selective security mechanisms** in hardware design.  
The project is based on an implementation of **Dilithium** and applies a **majority-voter flip-flop architecture** to improve resilience against **fault injection attacks**.

The repository includes RTL implementations, testbenches, simulation results, and written documentation.

---

## Project Structure

### `flipflops/`
Contains:
- Flip-flop implementations
- Corresponding testbenches used for functional verification

---

### `fully_secure/`
*(Not pushed yet — currently running locally)*

- Vivado project for the **fully secured design**
- Every flip-flop in the design is protected using the security mechanism

---

### `selective_security/`
- Vivado project for the **selectively secured design**
- Only specific registers or system states are protected

---

### `TEXTE/`
- Collection of notes, background material, and important design explanations
- Serves as the primary documentation and reference folder for the project

---

## Verilog Source Files

### `fully_secure.v`
Verilog implementation of the **fully secured design**.

---

### `partly_secure_selective_trm.v`
Verilog implementation of the **selective security design**,  
where only the **final-state registers** are protected.

---

### `partly_secure.v`
Vivado-generated reference design  
(exported using `write_verilog`).

The file name will be changed in the future to improve clarity and overall project structure.  
For the time being, it is kept unchanged.

---

## Current Status

- A simulation of `fully_secure.v` is currently running locally
- Additional simulations and evaluations are planned

---

## Notes

- The project structure is still evolving
- File and folder names may be adjusted to improve clarity and maintainability
- All relevant background information and design notes can be found in the `TEXTE` directory
