import csv
import json

# Open the CSV file and read its contents
with open("./data/NLP2SelectionRulesAttributesCSV.csv", "r") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

# Convert the array of dictionaries into a JSON array
json_array = json.dumps(rows, indent=4)

# Write the JSON array to an output file
with open("./data/NLP2SelectionRulesAttributesJSON.json", "w") as f:
    f.write(json_array)
