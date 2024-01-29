#!/bin/bash

file_path="README.md"

# Extract values from the 'Algorithm' column (excluding header and divider) and append to a list
algorithm_values=()
start_extraction=false
while IFS= read -r line; do
    if [[ "$line" = "| ---"* ]]; then
        echo "Found divider"
        start_extraction=true
        continue
    fi
    
    if [[ "$start_extraction" == true && "$line" =~ \| ]]; then
        algo=$(echo "$line" | awk -F '|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        echo "algo: $algo"
        [ -n "$algo" ] && algorithm_values+=("$algo")
    fi
done < "$file_path"

# Print the extracted algos
echo "algos in 'Algorithm' column (excluding header and divider):"
for algo in "${algorithm_values[@]}"; do
    echo "$algo"
    # Extract the value of 'pdf' CC1
    HFEN=$(awk -F '|' '/'"$algo"'/ {print $3}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo HFEN: $HFEN"
    NMI=$(awk -F '|' '/'"$algo"'/ {print $4}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo NMI: $NMI"
    RMSE=$(awk -F '|' '/'"$algo"'/ {print $5}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo RMSE: $RMSE"
    MAD=$(awk -F '|' '/'"$algo"'/ {print $6}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo MAD: $MAD"
    CC1=$(awk -F '|' '/'"$algo"'/ {print $7}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo CC1: $CC1"
    CC2=$(awk -F '|' '/'"$algo"'/ {print $8}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo CC2: $CC2"
    GXE=$(awk -F '|' '/'"$algo"'/ {print $9}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo GXE: $GXE"
    NRMSE=$(awk -F '|' '/'"$algo"'/ {print $10}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo NRMSE: $NRMSE"
    XSIM=$(awk -F '|' '/'"$algo"'/ {print $11}' "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Value for $algo XSIM: $XSIM"
    SUM=$(echo "$HFEN + $NMI + $RMSE + $MAD + $CC1 + $CC2 + $GXE + $NRMSE + $XSIM" | bc)
    echo "Sum of all metrics $SUM"
done

# Values to append to the next row
new_values=("new_algorithm" "0.95" "0.75" "0.03" "0.12" "0.65" "0.80" "0.22" "0.05" "0.92")

# Read the content of the file
file_content=$(cat "$file_path")

# Find the position of the last row in the table
last_row_start=$(echo "$file_content" | grep -n '| ---' | tail -n 1 | cut -d ':' -f 1)
last_row_end=$((last_row_start + 1))

# Create a string with the new values
new_row=$(IFS='|'; echo "| ${new_values[*]} |")

# Insert the new row after the last row in the table
updated_content=$(echo "$file_content" | sed "${last_row_end}a $new_row")

# Write the updated content back to the file
echo "$updated_content" > "$file_path"