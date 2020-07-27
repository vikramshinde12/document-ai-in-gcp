import os
import json
from google.cloud import firestore
from google.cloud import pubsub_v1
from google.cloud import documentai_v1beta2 as documentai

project_id = os.environ.get('GCP_PROJECT')
topic_id = os.environ.get('ALERT_TOPIC')


def main(event, context):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    bucket = event['bucket']
    file = event['name']
    uri = f"gs://{bucket}/{file}"
    data = parse_form(input_uri=uri)
    employee_id = data['Employee #:']
    first_name = data['First Name:']
    last_name = data['Last Name:']
    data['email'] = f'{first_name.lower()}.{last_name.lower()}@example.com'
    add_into_firestore(data, employee_id)
    publish_message(employee_id)


def parse_form(input_uri):
    """Parse a form"""

    client = documentai.DocumentUnderstandingServiceClient()

    gcs_source = documentai.types.GcsSource(uri=input_uri)
    input_config = documentai.types.InputConfig(gcs_source=gcs_source, mime_type='application/pdf')

    # Improve form parsing results by providing key-value pair hints.
    # For each key hint, key is text that is likely to appear in the
    # document as a form field name (i.e. "DOB").
    # Value types are optional, but can be one or more of:
    # ADDRESS, LOCATION, ORGANIZATION, PERSON, PHONE_NUMBER, ID,
    # NUMBER, EMAIL, PRICE, TERMS, DATE, NAME
    key_value_pair_hints = [
        documentai.types.KeyValuePairHint(key='Emergency Contact',  value_types=['NAME']),
        documentai.types.KeyValuePairHint(key='Referred By')
    ]

    # Setting enabled=True enables form extraction
    form_extraction_params = documentai.types.FormExtractionParams(
        enabled=True, key_value_pair_hints=key_value_pair_hints)

    # Location can be 'us' or 'eu'
    parent = 'projects/{}/locations/us'.format(project_id)
    request = documentai.types.ProcessDocumentRequest(
        parent=parent,
        input_config=input_config,
        form_extraction_params=form_extraction_params)

    document = client.process_document(request=request)

    def _get_text(el):
        """Doc AI identifies form fields by their offsets
        in document text. This function converts offsets
        to text snippets.
        """
        response = ''
        # If a text segment spans several lines, it will
        # be stored in different text segments.
        for segment in el.text_anchor.text_segments:
            start_index = segment.start_index
            end_index = segment.end_index
            response += document.text[start_index:end_index]
        return response

    payload = dict()
    for page in document.pages:
        for form_field in page.form_fields:

            name = _get_text(form_field.field_name).rstrip()
            value = _get_text(form_field.field_value).rstrip()
            payload[name] = value

            # if _get_text(form_field.field_name) == 'Requester : Name':
            #     print('Field Name: {}\tConfidence: {}'.format(
            #         _get_text(form_field.field_name),
            #         form_field.field_name.confidence))
            #     print('Field Value: {}\tConfidence: {}'.format(
            #         _get_text(form_field.field_value),
            #         form_field.field_value.confidence))

    return payload


def add_into_firestore(message, employee_id):
    db = firestore.Client()
    doc_ref = db.collection(u'employee').document(u'{}'.format(employee_id))
    doc_ref.set(message)


def publish_message(message_id):
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(project_id, topic_id)
    data = {'message_id': message_id}
    data = json.dumps(data).encode("utf-8")
    # When you publish a message, the client returns a future.
    future = publisher.publish(topic_path, data=data)
    print(future.result())
