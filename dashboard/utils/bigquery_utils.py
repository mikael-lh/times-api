"""
NYT Analytics Dashboard - Utility functions for BigQuery and data processing
"""

import os

import pandas as pd
import streamlit as st
from dotenv import load_dotenv
from google.cloud import bigquery
from google.oauth2 import service_account

# Load environment variables
load_dotenv()


@st.cache_resource
def get_bigquery_client():
    """Initialize and cache BigQuery client"""
    try:
        # Try to use credentials from environment
        credentials_path = os.getenv("GCP_CREDENTIALS_PATH")
        project_id = os.getenv("GCP_PROJECT_ID", "times-api-ingest")

        if credentials_path and os.path.exists(credentials_path):
            credentials = service_account.Credentials.from_service_account_file(credentials_path)
            client = bigquery.Client(credentials=credentials, project=project_id)
        else:
            # Fall back to application default credentials
            client = bigquery.Client(project=project_id)

        return client
    except Exception as e:
        st.error(f"Failed to initialize BigQuery client: {str(e)}")
        st.info("Make sure you have set up your credentials. See README for instructions.")
        return None


@st.cache_data(ttl=3600)  # Cache for 1 hour
def run_query(_client, query: str) -> pd.DataFrame:
    """
    Run a BigQuery query and return results as DataFrame

    Args:
        _client: BigQuery client (prefixed with _ to avoid hashing by streamlit)
        query: SQL query string

    Returns:
        pandas DataFrame with query results
    """
    try:
        df = _client.query(query).to_dataframe()
        return df
    except Exception as e:
        st.error(f"Query failed: {str(e)}")
        return pd.DataFrame()


def format_number(num: float, decimals: int = 0) -> str:
    """Format number with commas and optional decimals"""
    if pd.isna(num):
        return "N/A"
    if decimals == 0:
        return f"{int(num):,}"
    return f"{num:,.{decimals}f}"


def format_percentage(num: float, decimals: int = 1) -> str:
    """Format number as percentage"""
    if pd.isna(num):
        return "N/A"
    return f"{num:.{decimals}f}%"


def get_dataset_name(dataset_type: str = "core") -> str:
    """Get dataset name from environment or use default"""
    defaults = {"core": "dbt_core", "analytics": "dbt_analytics", "staging": "dbt_staging"}
    env_key = f"DBT_{dataset_type.upper()}_DATASET"
    return os.getenv(env_key, defaults.get(dataset_type, "dbt_core"))


def get_project_id() -> str:
    """Get GCP project ID"""
    return os.getenv("GCP_PROJECT_ID", "times-api-ingest")


def get_table_path(dataset_type: str, table_name: str) -> str:
    """Construct full table path for BigQuery"""
    project = get_project_id()
    dataset = get_dataset_name(dataset_type)
    return f"`{project}.{dataset}.{table_name}`"
