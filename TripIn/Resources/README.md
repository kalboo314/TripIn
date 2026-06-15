# Resources

Drop the CoreML model here:

- `TravelRecommender.mlmodel` — tabular classifier.
  Inputs: Temperature, Humidity, WindSpeed, Precipitation, UVIndex,
  WeatherType, Season, Location → Output: `attraction_category` (String).

Add it in **Step 6**. When dragged into Xcode, it auto-generates a
`TravelRecommender` Swift class used by `MLRecommender`.
