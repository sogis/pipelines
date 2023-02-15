# Layerinfo module for usage in the context with uplus ews.
# Uses the heatdrill-service to query the Information at the klicked location.

import logging
import requests
from requests.adapters import HTTPAdapter
import sys
from os import environ
from urllib import parse

conf = {
    'timeout': 10,
    'baseurl': environ.get('HEATDRILL_SERVICE_URL'),
    'loglevel': logging.INFO
}

log = logging.getLogger(__name__)

def layer_info(layer, x, y, crs, params, identity):
    """Query the heatdrill-service and return info result as dict:

        {
            'features': [
                {
                    'attributes': [
                        {
                            'name': '<attribute name>',
                            'value': '<attribute value>'
                        }
                    ],
                    'geometry': '<WKT geometry>'  # optional
                },
                {...}
            ]
        }

    the optional feature.id, feature.bbox are not returned by this module.
    In case of success, x and y and the full attributes of the underlying service are returned.
    In case of error, x, y, requestId and infoTextRows are returned. The requestId is negative,
    infoTextRows contains the error message.

    :param str layer: Layer name - not used in module
    :param float x: X coordinate of query
    :param float y: Y coordinate of query
    :param str crs: CRS of query coordinates - not used in module
    :param obj params: FeatureInfo service params - not used in module
    :param str identity: User name or Identity dict - not used in module
    """
    res = None

    x = round(x)
    y = round(y)

    log.setLevel(conf['loglevel'])

    try:
        url = _buildServiceRequest(x, y)
        log.debug('Calling service ' + url)

        response = _queryService(url)

        res = _convertToFeatureDict(response, x, y)

    except:
        exInfo = sys.exc_info()
        log.error(exInfo[1])
        res = _return_error('Exception of type {} occured'.format(exInfo[0]), x, y)

    return res

def _convertToFeatureDict(response, x, y):
    """
    Converts the service response to the features response dict
    :param dict response: The response from the heatdrill service as dict
    :return dict: The features response dict. Return value of method layer_info(...)
    """
    attributes = [
        {
            'name': 'requestId',
            'value': response['requestId']
        },
        {
            'name': 'permitted',
            'value': response['permitted']
        },
        {
            'name': 'depth',
            'value': response['depth']
        },
        {
            'name': 'gwsZone',
            'value': response['gwsZone']
        },
        {
            'name': 'gwPresent',
            'value': response['gwPresent']
        },
        {
            'name': 'spring',
            'value': response['spring']
        },
        {
            'name': 'gwRoom',
            'value': response['gwRoom']
        },
        {
            'name': 'wasteSite',
            'value': response['wasteSite']
        },
        {
            'name': 'landslide',
            'value': response['landslide']
        },
        {
            'name': 'infoTextRows',
            'value': response['infoTextRows']
        },
        {
            'name': 'x',
            'value': x
        },
        {
            'name': 'y',
            'value': y
        }
    ]
    geometry = "POINT(%s %s)" % (x, y)

    featureDict = {'attributes': attributes, 'geometry': geometry}
    multiFeatureDict = {'features': [featureDict]}

    return multiFeatureDict

def _queryService(url):
    """
    Calls the heatdrill service and returns the dict of the service response attributes.

    Throws exeptions when status code != 200 / in case of timeouts
    :param str url: Full service url with query params
    :return dict: dict of the service response attributes
    """
    res = None

    from requests.adapters import HTTPAdapter

    s = requests.Session()
    s.mount(url, HTTPAdapter(max_retries=3))

    resp = requests.get(url, timeout=conf['timeout'])

    if resp.status_code != 200:
        resp.raise_for_status()

    res = resp.json()

    return res

def _buildServiceRequest(x, y):
    query = '?x={}&y={}'.format(x, y)
    return parse.urljoin(conf['baseurl'], query)

def _return_error(usr_msg, x, y, log_msg=None):
    """
    Helper method to log error and return error feature for user display
    :param str usr_msg: Error message for the user
    :param str log_msg: Error message for the log
    :param float x: X coordinate of query
    :param float y: Y coordinate of query
    :return: Feature array (see returnvalue signature of layer_info)
    """
    if not log_msg:
        log_msg = usr_msg

    log.error(log_msg)

    attributes = [
        {
            'name': 'requestId',
            'value': -1
        },
        {
            'name': 'infoTextRows',
            'value': ['Fehler in der Ausführung der Layerinfo-Abfrage:','',usr_msg]
        },
        {
            'name': 'x',
            'value': x
        },
        {
            'name': 'y',
            'value': y
        }
    ]
    geometry = "POINT(%s %s)" % (x, y)

    features = []
    features.append({
        'attributes': attributes,
        'geometry': geometry
    })

    return {'features': features}


def _testInit(baseurl, timeout):
    """
    Method to inject configuration for unit testing purpose
    :param str baseurl: Base url of the heatdrill service
    :param float timeout: Timeout in seconds for the heatdrill service call
    :param loglevel: Loglevel for this module. Example: logging.DEBUG
    """
    conf['timeout'] = timeout
    conf['baseurl'] = baseurl
