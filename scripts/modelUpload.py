import os, sys, getopt
import boto3

key_id = os.getenv("AWS_ACCESS_KEY_ID")
secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
region = os.getenv("AWS_DEFAULT_REGION")
endpoint = os.getenv("AWS_S3_ENDPOINT")
bucket_name = os.getenv("AWS_S3_BUCKET")

print ("S3 parameters:")
print (key_id)
print (secret_key)
print (region)
print (endpoint)
print (bucket_name)
print ()

# folder where Podman AI models are kept
homeFolder= os.path.expanduser('~')
baseFolder=os.path.join(homeFolder, 
  ".local/share/containers/podman-desktop/extensions-storage/redhat.ai-lab/models")
print ("Podman AI model base folder:")
print (baseFolder)
print ()

# Sample sourceSubfolder and targetSubfolder values
# sourceSubfolder: Llama-2-7b-chat-hf-sharded-bf16-caikit
# targetSubfolder: llm-trelis-llama-2-7b-caikit

# Let's default to Llama2 7B
# sourceSubfolder: Llama-2-7b-chat-hf-sharded-bf16
# targetSubfolder: llm-trelis-llama-2-7b/"

# sourceSubfolder: merlinite-7b-lab-GGUF
# targetSubfolder: vLLM/"

# sourceSubfolder: granite-7b-lab-GGUF
# targetSubfolder: granite-7b-lab-GGUF

# sourceSubfolder: hf.instructlab.granite-7b-lab-GGUF
# targetSubfolder: hf.instructlab.granite-7b-lab-GGUF


sourceSubfolder = sys.argv[1]
targetSubfolder = sys.argv[2]
print ("source and target directories:")
print (sourceSubfolder)
print (targetSubfolder)
print ()

full_source_path = os.path.join(baseFolder, sourceSubfolder)
print ("Full source folder path:")
print (full_source_path)
print ()


s3 = boto3.client(
   "s3",
   aws_access_key_id=key_id,
   aws_secret_access_key=secret_key,
   endpoint_url=endpoint,
   verify=True)


files = os.listdir(full_source_path)

files = [f for f in files if os.path.isfile(os.path.join(full_source_path, f))]


print ("Uploading files:")
for filename in files:
  sourceFile = os.path.join(full_source_path, filename)
  targetFile = os.path.join(targetSubfolder, filename)

  print(sourceFile)
  print(targetFile)

  s3.upload_file(sourceFile, bucket_name, targetFile)


print ("Done")