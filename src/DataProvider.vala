using Gee;
using Gtk;

namespace Gradio{

	public enum Search {
		BY_ID,
		BY_NAME,
		BY_NAME_EXACT,
		BY_CODEC,
		BY_COUNTRY,
		BY_COUNTRY_EXACT,
		BY_STATE,
		BY_STATE_EXACT,
		BY_LANGUAGE,
		BY_LANGUAGE_EXACT,
		BY_TAG,
		BY_TAG_EXACT,
	}

	public class DataProvider{
		public static string radio_stations = "http://www.radio-browser.info/webservice/json/stations/";
		public static string by_name = "byname/";

		private bool _isWorking = false;
		public signal void status_changed();

		public bool isWorking { get { return _isWorking;} set { _isWorking = value; status_changed();}}

		public int vote_for_station(RadioStation station){
			Json.Parser parser = new Json.Parser ();
			RadioStation new_station = null;
			try{
				parser.load_from_data (Util.get_string_from_uri("http://www.radio-browser.info/webservice/json/vote/" + station.ID));
				var root = parser.get_root ();
				var radio_stations = root.get_array ();

				var radio_station = radio_stations.get_element(0);
				var radio_station_data = radio_station.get_object ();
						
				new_station = parse_station_data_from_json(radio_station_data);
			}catch (Error e){
				error("Parser: " + e.message);
			}
			
			return int.parse(new_station.Votes);
		}

		public RadioStation parse_station_data_from_id (int id){
			Json.Parser parser = new Json.Parser ();
			RadioStation new_station = null;
			try{
				parser.load_from_data (Util.get_string_from_uri("http://www.radio-browser.info/webservice/json/stations/byid/" + id.to_string()));
				var root = parser.get_root ();
				var radio_stations = root.get_array ();

				var radio_station = radio_stations.get_element(0);
				var radio_station_data = radio_station.get_object ();

				new_station = parse_station_data_from_json(radio_station_data);
			}catch (Error e){
				error("Parser: " + e.message);
			}

			return new_station;
		}

		public RadioStation parse_station_data_from_json (Json.Object radio_station_data){
			string title = radio_station_data.get_string_member("name");
			string homepage = radio_station_data.get_string_member("homepage");
			string source = radio_station_data.get_string_member("url");
			string language = radio_station_data.get_string_member("language");
			string id = radio_station_data.get_string_member("id");
			string icon = radio_station_data.get_string_member("favicon");
			string country = radio_station_data.get_string_member("country");
			string tags = radio_station_data.get_string_member("tags");
			string state = radio_station_data.get_string_member("state");
			string votes = radio_station_data.get_string_member("votes");
			string codec = radio_station_data.get_string_member("codec");
			string bitrate = radio_station_data.get_string_member("bitrate");
			bool available;
						
			if(radio_station_data.get_string_member("lastcheckok") == "1")
				available = true;
			else
				available = false;

			if(source.contains(".m3u") || source.contains(".pls"))
				available = false;

			RadioStation station = new RadioStation(title, homepage, source, language, id, icon, country, tags, state, votes, codec, bitrate, available);
			return station;	
		}

		public async HashMap<int,RadioStation> get_radio_stations(string address, int max_results) throws ThreadError{
			SourceFunc callback = get_radio_stations.callback;
			HashMap<int,RadioStation> output = new HashMap<int,RadioStation>();

			isWorking = true;
			ThreadFunc<void*> run = () => {
				try{
		   			HashMap<int,RadioStation> results = new HashMap<int,RadioStation>();
					
					Json.Parser parser = new Json.Parser ();
					parser.load_from_data (Util.get_string_from_uri(address));
					var root = parser.get_root ();
					var radio_stations = root.get_array ();

					int max_items = (int)radio_stations.get_length();
					if(max_items < max_results)
						max_results = max_items;					

					for(int a = 0; a < max_results; a++){
						var radio_station = radio_stations.get_element(a);
						var radio_station_data = radio_station.get_object ();
						
						var station = parse_station_data_from_json(radio_station_data);

						results[int.parse(station.ID)] = station;
					}
					
					output = results;
				}catch(GLib.Error e){
					warning(e.message);
				}
				
				Idle.add((owned) callback);
				Thread.exit (1.to_pointer ());
				return null;
			};

			new Thread<void*> ("search_thread", run);

			yield;
			isWorking = false;
           		return output;
        	}
	}
}

