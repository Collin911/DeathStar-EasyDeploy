#!/bin/bash
set -e

# === CONFIGURATION ===
REPO_URL="https://github.com/Collin911/DeathStar-EasyDeploy.git"
BASE_DIR="$HOME/DeathStarBench"
NAMESPACE=socialnetwork

# ======================
# This script assumes you have kubectl and helm installed and configured properly.

# 1. Clone the original repo if it doesn't exist
if [ ! -d "$BASE_DIR" ]; then
  echo "📥 Cloning DeathStarBench repository..."
  git clone "$REPO_URL" "$BASE_DIR"
fi

cd "$BASE_DIR"

echo "🔄 Applying Pull Request #352..."
cd "$BASE_DIR"
git reset --hard HEAD
git clean -fd
git checkout master
git pull origin master
git fetch origin pull/352/head:pr-352
git checkout pr-352
echo "✅ Pull Request #352 applied."

# 2. Initialize submodules
echo "🔄 Updating submodules..."
git submodule update --init --recursive

# 2. Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
  echo "🌐 Creating '$NAMESPACE' namespace..."
  kubectl create namespace "$NAMESPACE"
fi
# Switch to the hotel namespace
kubectl config set-context --current --namespace="$NAMESPACE"
echo "✅ Using '$NAMESPACE' namespace."


# 3. Deploy Social Network app using Helm
echo "📦 Deploying Social Network using Helm..."
cd "$BASE_DIR/socialNetwork"
helm install social-network ./helm-chart/socialnetwork -n socialnetwork
echo "✅ DeathStarBench reinstalled."

# 4. Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod --all -n socialnetwork --timeout=300s

echo "Exposing Nginx as NodePort..."
kubectl patch svc nginx-thrift -n socialnetwork -p '{"spec": {"type": "NodePort"}}'
echo "✅ Nginx exposed as NodePort."

# 5. Output end message
echo "✅ Social Network deployed in namespace 'socialnetwork'."

# 6. Build WRK2 in the Correct Directory
# This is for the load generator, comment out if not needed
sudo apt install libssl-dev
sudo apt install zlib1g-dev
sudo apt-get install luarocks
sudo luarocks install luasocket
echo "⚙️ Building WRK2..."
cd "$BASE_DIR/wrk2/"
make
echo "✅ WRK2 built successfully."

# 7. Final message
echo "Next step: run python3 scripts/init_social_graph.py --graph=socfb-Reed98 --ip=<KIND_IP> -port=<NGINX_PORT> to initialize the social graph."
echo " run ../wrk2/wrk -D exp -t <num-threads> -c <num-conns> -d <duration> -L -s ./wrk2/scripts/social-network/compose-post.lua http://<KIND_IP>:<NGINX_PORT>/wrk2-api/post/compose -R <reqs-per-sec> to generate load."