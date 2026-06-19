from tools.run_api_calls import get_basic_sql_def, get_str_attrib_values
import csv
import json


def sql_def_2_json(sql_def_name: str):
    sql_def = get_basic_sql_def(sql_def_name)
    attrib_list = []
    build_attribute_list(sql_def, attrib_list)
    json_array = json.dumps(attrib_list, indent=4)
    with open("./data/basic_rule_attributes.json", "w") as f:
        f.write(json_array)


def build_attribute_list(curr_dict: dict, attrib_list: list):
    for key, val in curr_dict.items():
        if key == "attributes" and isinstance(val, list):
            if len(val) > 0:
                for attrib in val:
                    samples = "No samples available for this attribute"
                    attrib_id = attrib["attribute"]["id"]
                    if attrib["attribute"]["dataType"] == "String":
                        samples = get_str_attrib_values(attrib_id)
                    attrib_record = {
                                     "attribute_name": attrib["name"],
                                     "attribute_group_id": attrib["parentTableDefinitionID"],
                                     "attribute_datatype": attrib["attribute"]["dataType"],
                                     "attribute_id": attrib_id,
                                     "attribute_sample_values": samples
                                     }
                    attrib_list.append(attrib_record)

        elif key == "nestedTableDefinitions" and isinstance(val, list):
            if len(val) > 0:
                for tableDef in val:
                    build_attribute_list(tableDef, attrib_list)
        else:
            continue


if __name__ == "__main__":
    sql_def_2_json("3Cloud POC")
