import re

input_file  = "partly_secure.v"
output_file = "fully_secure.v"

with open(input_file, "r") as f:
    text = f.read()

text = re.sub(r'\bFDRE\b', 'trm_fdre', text)
text = re.sub(r'\bFDSE\b', 'trm_fdse', text)

# text = re.sub(r'\bFDCE\b', 'trm_fdce', text)
# text = re.sub(r'\bFDPE\b', 'trm_fdpe', text)

with open(output_file, "w") as f:
    f.write(text)

print("Done!")
print("Output written to:", output_file)
