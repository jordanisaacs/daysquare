# Identity

Set up Kubernetes with Contour Ingress. Contour will perform the mutual TLS and forward plaintext certificate to backend for authentication

Frontend posts to redact client `/proxy` -> redact client forwards request as get to backend -> contour performs mutual TLS with client and forwards certificate to backend -> backend creates/gets user with authority key identifier and creates a session -> sends a message to the frontend with session
