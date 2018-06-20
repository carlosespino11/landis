import logging


from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.common.by import By
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.support import expected_conditions as EC
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from bs4 import BeautifulSoup
import requests
import pandas as pd
from multiprocessing import Pool
import pymysql.cursors
import sys

from datetime import datetime
import dateutil.parser as parser
from collections import OrderedDict

ch = logging.StreamHandler()


hdlr = logging.FileHandler('scraper.log')

# Create log formatter
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
ch.setFormatter(formatter)

logger = logging.getLogger('SQLLogger')
hdlr.setFormatter(formatter)

logger.addHandler(ch)
logger.addHandler(hdlr) 

logger.setLevel(logging.DEBUG)

options = Options()
options.set_headless()



base_url = 'https://property.spatialest.com/nc/mecklenburg/' 
table = 'properties'

def request_wait_until_loaded(driver, url, selector, delay=30):
    """
    Summary
    
    Makes a request using selenium driver and returns the HTML text after
    waiting until DOM defined by selector is loaded by the driver.
    
    Parameters
    ----------
    driver : webdriver
        A selenium webdriver object
    url : str
        Request URL
    selector: str
        CSS-like selector for the DOM to wait to be loaded
    delay: int
        Time in seconds to wait for the DOM to load

    Returns
    -------
    str
        A string containing the HTML of the URL requested
    """
    logger.info('Loading {}'.format(url))
    
    # Trigger driver to load url
    driver.get(url)
    
    # Wait until driver loads DOM corresponding to selector or until time delay is met  
    try:
        myElem = WebDriverWait(driver, delay).until(EC.presence_of_element_located((By.CSS_SELECTOR, selector)))
        logger.info("Loaded {}".format(url))
    except TimeoutException:
        raise
    
    # Get HTML text
    html_text = driver.page_source
    
    return(html_text)

def get_house_attributes(house_soup, remote_id):
    """
    Summary
    
    Parses a BeautifulSoup object containing the info of a house in HTML
    
    Parameters
    ----------
    house_soup : BeautifulSoup
        BeautifulSoup object containing the info of a house
    remote_id : str
        House id given by the search 
                
    Returns
    -------
    dict
        A dictionary with the attributes of the house
    """
    
    # Get all data lists. Data lists contain the attribute of the houses
    data_lists = house_soup.findAll("ul", {"class": "data-list"})
    
    house_attrs = {}
    house_attrs['remote_id'] = remote_id
    for data_list in data_lists:

        for data_li in data_list.findChildren('li'):
            try:
                # Get and clean the name of the title
                title = data_li.find('span', {"class": "title"} ).text
                title = title.lower().replace(" ","_").replace("(","").replace(")", "").replace('_/', '')
                
                # Get the value corresponding to the title
                value = data_li.find('span', {"class": "value"} ).text
                
                # Add to the dicionary of attributes
                house_attrs[title] = value
            except:
                pass
    
    # Get all featurette lists. Featurettt lists contain the main information of the houses
    main_feats = house_soup.findAll("div", {"class": "featurette"})

    for feat in main_feats:
        
        # Get and clean the name of the title
        title = feat.find('h4').text
        title = title.lower().replace(" ","_").replace("(","").replace(")", "").replace('_/', '')
        
        # Get the value corresponding to the title
        value = feat.find('span', {"class": "value"}).text
        
        # Add to the dicionary of attributes
        house_attrs[title] = value
        
    return(house_attrs)

def parse_house_results(house_results, driver, connection):
    """
    Summary
    
    Parses a BeautifulSoup object containing the listing of houses in HTML. It returns a list
    with the attributes of each of the houses in the listing.
    
    Parameters
    ----------
    house_soup : BeautifulSoup
        BeautifulSoup object containing the listing of houses
    
    driver : Selenium Webdriver
        A selenium Webdriver
    
    house_soup : PyMySQL dconnection
        A PyMySQL dconnection  
    Returns
    -------
    array
        list with the attributes of each of the houses in the listing.
    """

    
    # Initialize an empty list
    houses = []
    
    for house_item in house_results:
        try:
            # Get suffix of the link to the complete info of the house
            house_link = house_item.find('a')
            house_suffix = house_link.attrs['href']
            remote_id = house_suffix.split('/')[-1]

            if not property_in_db(remote_id, connection):
                # Build house url
                house_url = base_url + house_suffix
                
                # Get HTML text with selenium.
                house_html = request_wait_until_loaded(driver, house_url ,'ul.data-list', delay=60)
                house_soup = BeautifulSoup(house_html, "lxml")

                # Parse the house soup
                house_attrs = get_house_attributes(house_soup, remote_id)
                db_fields = prepare_attrs(house_attrs)

                # Insert attributes
                insert_property(db_fields, connection)

                houses.append(db_fields)

        except TimeoutException:
            logger.error("Timeout: " + remote_id)
            pass
    return houses



    
def scrape_search_url(search_url):
    """
    Summary
    
    Parse all results from a search url
    
    Parameters
    ----------
    seaurch_url : str
        Search Url
     
    Returns
    -------
    array
        list with the attributes of each of the houses returned by the search URL
    """

    # Initialize empty array
    all_houses = []

    # Initialize selenium driver and pymsql connection 
    driver = webdriver.Firefox(options=options)
    connection = pymysql.connect(host='localhost',
                         user='root',
                         db='landis',
                         cursorclass=pymysql.cursors.DictCursor)
    logger.info('Processing: '  +  search_url)

    # Flag to check if there are more results in the next pages
    more_results = True
    page_num = 1

    while more_results:
        try:

            # Fuild search url adding pagination
            page_url = '{}/{}'.format(search_url, page_num)
            
            # Fetch, parse  and find results
            html_text = request_wait_until_loaded(driver, page_url ,'div.search-results', delay=10) #driver.page_source    
            listings_soup = BeautifulSoup(html_text, "lxml")
            house_results =  listings_soup.findAll("div", {"class": "resultItem"})

            # If no new results, set more_results to False
            if len(house_results) ==0:
                more_results = False
            
            # Parse the list of properties and insert into DB
            houses = parse_house_results(house_results, driver, connection)

            # Add parsed info to list
            all_houses = all_houses + houses
            page_num += 1

        except KeyboardInterrupt:
            raise
        except TimeoutException:
            more_results = False
            pass
        except Exception as e:
            raise

    connection.close()
    driver.close()

    return(all_houses)




def prepare_attrs(house_attrs):
    """
    Summary
    
    Given a dictionary of attributes of a property, cleans and parses the fields to
    the correct format corresponding to the schema
    
    Parameters
    ----------
    house_attrs : dict
        A dictionary with attributes of a property
     
    Returns
    -------
    dict
        Formatted dictionary
    """

    # Identify fields by type
    db_fields = OrderedDict()


    currency_fields = ['assessment', 'building_value', 'sale_price', 'features', 'land_value',
                      'last_sale_price', 'sale_price']

    date_fields = ['last_sale_date', 'sale_date', 'issue_date']

    char_fields = [ "account", "built_use_style", "current_owners", "deed_type", "description", "external_wall",
                   "foundation", "fuel", "heat", "land", "land_use_code", "land_use_desc", "legal_description",
                   "legal_reference", "location_address"  "luc_at_sale", "mailing_address", "neighborhood", "parcel_id",
                   "permit_number", "story"
                  ]

    int_fields = ["account_no", "units"  , "year_built" , "bedrooms",
                  "fireplaces" , "full_baths" , "half_baths"]

    float_fields = ["amount", "heated_area", "sale_price", "total_sqft"]

    db_fields['remote_id'] = house_attrs['remote_id']

    # Parse all the fields according to their format. If some field parsing fails, it won't be inserted
    for field in currency_fields:
        try:
            db_fields[field]= float(house_attrs.get(field, None).replace('$','').replace(',','')) 
        except:
            pass

    for field in date_fields:
        try:
            db_fields[field]=datetime.strptime(house_attrs.get(field, None), "%d/%m/%Y").strftime('%Y-%m-%d')
        except:
            pass

    for field in char_fields:
        try:
            attr= house_attrs.get(field, '-')
            if attr  != '-':
                db_fields[field] = attr
        except:
            pass

    for field in int_fields:
        try:
            db_fields[field]= int(house_attrs.get(field, None))
        except:
            pass
    for field in float_fields:
        try:
            db_fields[field]= float(house_attrs.get(field, None))
        except:
            pass

    return(db_fields)

def property_in_db(remote_id,  connection):
    """
    Summary
    
    Check if a property is already in the db
    
    Parameters
    ----------
    remote_id : str
        House id given by the search
    
    connection : pymysql connection
        A selenium Webdriver
    
    Returns
    -------
    bool
        True if the property is already in the db.
    """

    in_db = False

    # Query for the property_id
    with connection.cursor() as cursor:
        sql = 'select * from  %s where remote_id = %s' % (table,remote_id)
        cursor.execute(sql)
        connection.commit()

    # If  length of results is greater than 0, set in_db = True
    if len(cursor.fetchall())>0 :
        logger.warning("{} already in DB".format(remote_id))
        in_db = True
    return(in_db)

def insert_property(db_fields, connection):
    """
    Summary
    
    Check if a property is already in the db
    
    Parameters
    ----------
    remote_id : str
        House id given by the search
    
    connection : pymysql connection
        A selenium Webdriver
    
    Returns
    -------
    bool
        True if the property is already in the db.
    """

    success= True
    rem_id = db_fields['remote_id']
    logger.info("Inserting: {}".format(str(rem_id)))

    try: 
        with connection.cursor() as cursor:

            # Create a new record
            sql = "INSERT INTO %s (%s) VALUES(%s)" % (
                table, ",".join(db_fields.keys()), ",".join(["'{}'".format(str(v))  if isinstance(v, basestring) else str(v) for v in db_fields.values()]))

            cursor.execute(sql)

            # connection is not autocommit by default. So you must commit to save
            # your changes.
            connection.commit()
    except Exception as e:
        print(e)
        logger.error("Failed to insert: {}".format(str(rem_id)))
        success = False
    return(success)

def gen_url_from_price_range(price_low, price_high):
    """
    Summary
    
    Generate search URL given a price range
    
    Parameters
    ----------
    price_low : int
        Lower bound of the price range
    
    price_high : int
        Upper bound of the price range
    
    Returns
    -------
    str
        Search URL
    """
    link = 'https://property.spatialest.com/nc/mecklenburg/#/search/R100_luc:{}_{}_assessedvalue:charlotte_srcterm:allparcels.locationaddress_category'.format(price_low, price_high)
    return(link)

def scrape(search_url):
    return(scrape_search_url(search_url))


def main():
    ## Command line arugments
    args = sys.argv[1:]

    # Scrape from price
    from_price = int(args[0])
    # Scrape to price
    to_price = int(args[1])
    # Moving by
    by =  int(args[2])

    # Generate urls according to the aprameters
    all_url = [gen_url_from_price_range(price_low+1, price_low+by) for price_low in range(from_price, to_price, by)]
    
    # Threading
    p = Pool(10) 

    # Scrape each url in  threads
    records = p.map(scrape_search_url, all_url)
    p.terminate()
    p.join()

    # The results are also stored in memory in case we want to do somethin else 
    houses =  [house for record in records for house in record]
    


if __name__== "__main__" :
    main()
