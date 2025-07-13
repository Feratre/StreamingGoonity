# main.py
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.textinput import TextInput
from kivy.uix.button import Button
from kivy.uix.label import Label
import requests
import sys

# Controllo se siamo su Android
def is_android():
    return hasattr(sys, 'getandroidapilevel')

if is_android():
    from jnius import autoclass, cast
    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    Intent = autoclass('android.content.Intent')
    Uri = autoclass('android.net.Uri')

def apri_url(link):
    if is_android():
        activity = PythonActivity.mActivity
        intent = Intent(Intent.ACTION_VIEW, Uri.parse(link))
        activity.startActivity(intent)
    else:
        import webbrowser
        webbrowser.open(link)

API_KEY = "80157e25b43ede5bf3e4114fa3845d18"
url_F = "https://api.themoviedb.org/3/search/movie"
url_S = "https://api.themoviedb.org/3/search/tv"

class StreamingApp(App):
    def build(self):
        self.layout = BoxLayout(orientation='vertical', padding=10, spacing=10)

        self.input_type = TextInput(hint_text="Film (F) o Serie (S)?")
        self.layout.add_widget(self.input_type)

        self.title_input = TextInput(hint_text="Titolo")
        self.layout.add_widget(self.title_input)

        self.season_input = TextInput(hint_text="Stagione (solo per Serie)")
        self.layout.add_widget(self.season_input)

        self.episode_input = TextInput(hint_text="Episodio (solo per Serie)")
        self.layout.add_widget(self.episode_input)

        self.button = Button(text="Cerca e apri link")
        self.button.bind(on_press=self.search)
        self.layout.add_widget(self.button)

        self.result = Label()
        self.layout.add_widget(self.result)

        return self.layout

    def search(self, instance):
        tipo = self.input_type.text.strip().lower()
        titolo = self.title_input.text.strip()

        if tipo == 'f':
            params = {"api_key": API_KEY, "query": titolo}
            response = requests.get(url_F, params=params)
            data = response.json()
            if data["results"]:
                movie = data["results"][0]
                tmdb_id = movie["id"]
                url = f"https://vixsrc.to/movie/{tmdb_id}"
                self.result.text = f"Apro: {url}"
                apri_url(url)
            else:
                self.result.text = "Film non trovato."

        elif tipo == 's':
            stagione = self.season_input.text.strip()
            episodio = self.episode_input.text.strip()
            params = {"api_key": API_KEY, "query": titolo}
            response = requests.get(url_S, params=params)
            data = response.json()
            if data["results"]:
                serie = data["results"][0]
                tmdb_id = serie["id"]
                url = f"https://vixsrc.to/tv/{tmdb_id}/{stagione}/{episodio}"
                self.result.text = f"Apro: {url}"
                apri_url(url)
            else:
                self.result.text = "Serie non trovata."
        else:
            self.result.text = "Inserisci 'F' o 'S'."

if __name__ == '__main__':
    StreamingApp().run()

