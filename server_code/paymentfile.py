from flask import request, jsonify
from paypalcheckoutsdk.core import PayPalHttpClient, SandboxEnvironment
from paypalcheckoutsdk.orders import OrdersCreateRequest, OrdersCaptureRequest
import os

# ------------------------------
# PayPal Client Setup
# ------------------------------
class PayPalClient:
    def __init__(self):
        self.client_id = ("PAYPAL_CLIENT_ID")
        self.client_secret = ("PAYPAL_CLIENT_SECRET")

        environment = SandboxEnvironment(
            client_id=self.client_id,
            client_secret=self.client_secret
        )
        self.client = PayPalHttpClient(environment)

paypal_client = PayPalClient().client

# ------------------------------
# Helper: convert PayPal SDK result to JSON serializable dict
# ------------------------------
def result_to_dict(obj):
    if isinstance(obj, list):
        return [result_to_dict(i) for i in obj]
    elif hasattr(obj, "__dict__"):
        return {k: result_to_dict(v) for k, v in obj.__dict__.items() if not k.startswith("_")}
    else:
        return obj

# ------------------------------
# Functions for routes
# ------------------------------

def create_order():
    data = request.get_json(silent=True) or {}
    amount = data.get("amount", "30.00")  # default amount if missing

    request_order = OrdersCreateRequest()
    request_order.prefer("return=representation")
    request_order.request_body({
        "intent": "CAPTURE",
        "purchase_units": [
            {
                "amount": {
                    "currency_code": "USD",  # Change to INR if your account supports it
                    "value": str(amount)
                }
            }
        ],
        "application_context": {
            "return_url": "http://192.168.29.214:5000/return",
            "cancel_url": "http://192.168.29.214:5000/cancel",
            "shipping_preference": "NO_SHIPPING",   # ✅ hides all address fields
            "user_action": "PAY_NOW"                # ✅ shows "Pay Now" instead of "Continue"
        }
    })

    try:
        response = paypal_client.execute(request_order)

        approval_url = next(
            (link.href for link in response.result.links if link.rel == "approve"), None
        )

        return jsonify({
            "approval_url": approval_url,
            "order_id": response.result.id,
            "amount": amount
        })

    except Exception as e:
        print(f"Error creating PayPal order: {e}")
        return jsonify({"error": "Failed to create PayPal order"}), 500


def capture():
    """Capture a PayPal order after approval."""
    order_id = request.args.get("token")
    if not order_id:
        return jsonify({"error": "Missing order ID"}), 400

    capture_request = OrdersCaptureRequest(order_id)
    capture_request.request_body({})
    capture_response = paypal_client.execute(capture_request)

    details = result_to_dict(capture_response.result)

    return jsonify({
        "status": capture_response.result.status,
        "order_id": order_id,
        "details": details
    })


def return_from_paypal():
    """Return endpoint after PayPal approval."""
    return jsonify({"message": "Payment was approved. Capture this order via /capture?token=ORDER_ID"})


def cancel():
    """Cancel endpoint if user cancels the payment."""
    return jsonify({"status": "cancelled", "message": "Payment cancelled by user."})
