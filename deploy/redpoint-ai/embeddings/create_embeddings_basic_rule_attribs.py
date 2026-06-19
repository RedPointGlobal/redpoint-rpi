# Import required libraries
import os
import json
import openai
from dotenv import load_dotenv
from tenacity import retry, wait_random_exponential, stop_after_attempt
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.models import Vector
from azure.search.documents.indexes.models import (
    SearchIndex,
    SearchField,
    SearchFieldDataType,
    SimpleField,
    SearchableField,
    SearchIndex,
    SemanticConfiguration,
    PrioritizedFields,
    SemanticField,
    SearchField,
    SemanticSettings,
    VectorSearch,
    HnswVectorSearchAlgorithmConfiguration,
)

# Configure environment variables
load_dotenv()
# service_endpoint = os.getenv("AZURE_SEARCH_SERVICE_ENDPOINT")
# index_name = os.getenv("AZURE_SEARCH_INDEX_NAME")
# key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
openai.api_type = "azure"
openai.api_key = os.getenv("OPENAI_API_KEY")
openai.api_base = os.getenv("OPENAI_API_BASE")
openai.api_version = os.getenv("OPENAI_API_VERSION")
# credential = AzureKeyCredential(key)

# Generate Document Embeddings using OpenAI Ada 002


with open("./data/basic_rule_attributes.json", "r", encoding="utf-8") as file:
    input_data = json.load(file)


@retry(wait=wait_random_exponential(min=1, max=20), stop=stop_after_attempt(3))
def generate_embeddings(text):
    response = openai.Embedding.create(input=text, engine="text-embedding-ada-002")
    embeddings = response["data"][0]["embedding"]
    return embeddings


for item in input_data:
    attribute_name = item["attribute_name"]
    attribute_sample_values = item["attribute_sample_values"]
    name_embeddings = generate_embeddings(attribute_name)
    sample_vals_embeddings = generate_embeddings(attribute_sample_values)
    item["attribute_name_vector"] = name_embeddings
    item["attribute_sample_values_vector"] = sample_vals_embeddings

# Output embeddings to docVectors.json file
with open("./data/basic_rule_attributes_vectorized.json", "w") as f:
    json.dump(input_data, f)
