import csv
import io
import json
import os
import argparse

# --- Configuration (Mapping based on your defined 4-column structure) ---
# NOTE: The actual column names in your CSV headers were:
# round.csv: weight, length, Height, code (We treat weight as Width)
# rectangle.csv: width, length, height, code
MAPPING = {
    0: "width",
    1: "length",
    2: "height",
    3: "code",
}

def parse_csv_to_list(file_path):
    """
    Reads a CSV file path, intelligently skips header rows, and extracts data
    into a list of dictionaries using a strict 4-column mapping.
    """
    if not os.path.exists(file_path):
        # We print an error but don't stop the whole process, just skip this file.
        print(f"Error: File not found at {file_path}")
        return []
        
    try:
        # NOTE: Using 'r' mode and 'utf-8' encoding for robust CSV reading.
        with open(file_path, 'r', encoding='utf-8') as f:
            string_data = f.read()

        # Convert string to a file-like object for the CSV reader
        stream = io.StringIO(string_data, newline=None)
        reader = list(csv.reader(stream))
        
        header_index = -1
        
        # 1. Intelligent Header Detection (Scanning first 20 rows)
        for i, row in enumerate(reader[:20]):
            row_str = ",".join([str(c).lower().strip() for c in row])
            # Look for keywords 'code' and ('width' or 'weight')
            if ('code' in row_str) and ('width' in row_str or 'weight' in row_str):
                header_index = i
                break
        
        if header_index == -1:
            print(f"Warning: Could not detect header row in {os.path.basename(file_path)}. Skipping file.")
            return []

        # 2. Extract Data (Strict 4-Column Mapping)
        extracted_data = []
        raw_data = reader[header_index + 1:]
        
        for row in raw_data:
            # Filter out empty cells
            clean_row = [cell for cell in row if cell and str(cell).strip() != '']
            
            if len(clean_row) >= 4:
                # We enforce the strict column order: Col 0 -> Width, Col 3 -> Code
                
                item = {
                    MAPPING[0]: clean_row[0].strip(), # Width
                    MAPPING[1]: clean_row[1].strip(), # Length
                    MAPPING[2]: clean_row[2].strip(), # Height
                    MAPPING[3]: clean_row[3].strip(), # Code
                }
                
                # Simple check to ensure the Code field is populated
                if item['code']:
                    extracted_data.append(item)
                
        return extracted_data

    except Exception as e:
        print(f"Error processing file {file_path}: {e}")
        return []

def generate_python_dataset_file(file_paths):
    """
    Parses multiple CSVs and generates the final Python file content.
    """
    all_data = []
    
    # Process files in the order provided
    for path in file_paths:
        data = parse_csv_to_list(path)
        all_data.extend(data)
        if data:
            print(f"Successfully processed {len(data)} records from {os.path.basename(path)}")
        
    
    # Format the list nicely as Python code string
    data_list_str = "STATIC_DATABASE = [\n"
    
    for item in all_data:
        # Use single quotes for dictionary keys/values and format neatly
        data_list_str += f'    {{"width": "{item["width"]}", "length": "{item["length"]}", "height": "{item["height"]}", "code": "{item["code"]}"}},\n'
        
    data_list_str += "]"
    
    return data_list_str

# --- Main Execution Block ---
if __name__ == '__main__':
    
    # --------------------------------------------------------
    # MODIFICATION: Hardcode file paths here, removing argparse
    # --------------------------------------------------------
    FILE_PATHS = [
        "/Users/klin/Documents/doshin/calculation continer fill in/dataset/rectangle.csv",
        "/Users/klin/Documents/doshin/calculation continer fill in/dataset/round.csv",
    ]
    
    OUTPUT_FILENAME = "dataset.py" # Define the output file name

    # 1. Generate the content
    final_content = generate_python_dataset_file(FILE_PATHS)
    
    # 2. Wrap it with the file header
    output = f"""# --- STATIC PRODUCT DATABASE ---
# Data automatically generated from the following files: {', '.join(FILE_PATHS)}
# Columns strictly mapped to: Width, Length, Height, Code.

{final_content}
"""
    # 3. Write the content to the output file
    try:
        with open(OUTPUT_FILENAME, 'w', encoding='utf-8') as f:
            f.write(output)
        
        print("\n" + "="*50)
        print(f"SUCCESS: Data saved automatically to {OUTPUT_FILENAME}")
        print("You can now import STATIC_DATABASE directly in your Streamlit app.")
        print("="*50)
        
    except Exception as e:
        print(f"\nERROR: Could not write file {OUTPUT_FILENAME}. Reason: {e}")
        # If saving fails, still print to console as fallback
        print("\nFallback output (Copy this content manually):")
        print("="*50)
        print(output)