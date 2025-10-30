# Project POC AROS

A proof-of-concept project demonstrating speech-to-text and text summarization capabilities using models deployed on OpenShift AI with vLLM serving runtime.

## Project Structure

### 📁 `audio_data/`
Contains audio samples for testing speech-to-text models:
- **`english/`** - English audio samples (9 files)
- **`danish/`** - Danish audio samples (5 files)

### 📁 `sample_emails/`
Insurance claims examples for testing summarization model:
- `claim1.json`, `claim2.json`, `claim3.json` - Sample insurance claim data

## Notebooks

### Speech-to-Text Testing
- **`whisper_http_only_transcription.ipynb`** - Transcribe English and Danish audio using HTTP endpoints
- **`whisper_openai_client.ipynb`** - Transcribe audio using OpenAI-compatible client

![Transcription Example 1](assets/images/example-transcribe-1.png)
![Transcription Example 2](assets/images/example-transcribe-2.png)

### Text Summarization Testing
- **`summarization.ipynb`** - Test summarization model with sample insurance claims

![Summary](assets/images/summary.png)

## Deployment

Two models are deployed in OpenShift AI cluster with vLLM as serving runtime:
- Speech-to-text model: Whisper-large-v3
- Text summarization model: Llama-3.1-8B-Instruct-quantized.w4a16 

Both models support internal and external endpoint access. **External URLs are pre-populated in the whisper notebooks.**

![External Endpoint Access](assets/images/external-endpoint.png)

> **Note**: API KEY required for external endpoint access.

## Usage

1. **Audio Transcription**: Run either whisper notebook with audio samples from `audio_data/`
2. **Text Summarization**: Run `summarization.ipynb` with sample emails from `sample_emails/`


