import os
from flask import Flask, jsonify
from google.cloud import firestore

app = Flask(__name__)


@app.route('/id/<id>')
def get_message(id):
    client = firestore.Client()
    doc_ref = client.collection(u'employee').document(u'{}'.format(id))
    doc = doc_ref.get()
    if doc.to_dict():
        return doc.to_dict()
    else:
        return "Not Found", 404


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))