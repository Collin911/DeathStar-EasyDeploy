#!/bin/bash
set -e

# === CONFIGURATION ===
REPO_URL="https://github.com/delimitrou/DeathStarBench.git"
BASE_DIR="$HOME/DeathStarBench"
NAMESPACE=hotel

# ======================
# This script assumes you have kubectl and helm installed and configured properly.

# 1. Clone the original repo if it doesn't exist
if [ ! -d "$BASE_DIR" ]; then
  echo "📥 Cloning DeathStarBench repository..."
  git clone "$REPO_URL" "$BASE_DIR"
fi

cd "$BASE_DIR"
# 2. Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
  echo "🌐 Creating '$NAMESPACE' namespace..."
  kubectl create namespace "$NAMESPACE"
fi
# Switch to the hotel namespace
kubectl config set-context --current --namespace="$NAMESPACE"
echo "✅ Using '$NAMESPACE' namespace."

# 3. Deploy Hotel Reservation app using k8s manifests
echo "📦 Deploying Hotel Reservation application..."
kubectl apply -Rf "$BASE_DIR/hotelReservation/kubernetes/" -n "$NAMESPACE"
echo "✅ Hotel Reservation application deployed."

# 4. Patch those deployment to use go
echo "🔧 Patching deployments to use 'go run'..."
SERVICES=(
  frontend
  geo
  profile
  rate
  recommendation
  reservation
  search
  user
)

for svc in "${SERVICES[@]}"; do
  echo "🔧 Patching deployment: $svc"

  kubectl patch deployment "$svc" -n "$NAMESPACE" \
    --type='json' \
    -p="[
      {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/command\",\"value\":[\"go\",\"run\",\"./cmd/$svc\"]},
      {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/workingDir\",\"value\":\"/workspace\"}
    ]"
done

echo "✅ Done."

# 4. Expose Frontend and Jaeger as NodePort
echo "Exposing Frontend and Jaeger as NodePort..."
kubectl patch svc frontend -n "$NAMESPACE" -p '{"spec": {"type": "NodePort"}}'
kubectl patch svc jaeger -n "$NAMESPACE" -p '{"spec": {"type": "NodePort"}}'
echo "✅ Frontend and Jaeger exposed as NodePort."

# 5. Output end message
echo "✅ Hotel Reservation deployed in namespace '$NAMESPACE'."

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
echo "../wrk2/wrk -D exp -t <num-threads> -c <num-conns> -d <duration> -L -s ./wrk2/scripts/hotel-reservation/mixed-workload_type_1.lua http://<KIND_IP>:<NGINX_PORT> -R <reqs-per-sec>"