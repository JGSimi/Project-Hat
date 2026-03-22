import Foundation

class ModelFetcher {
    static let shared = ModelFetcher()
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }
    
    /// Bate no endpoint `/v1/models` dos provedores compatíveis e retorna a lista de IDs de modelos disponíveis para a chave atual.
    func fetchModels(for provider: CloudProvider, apiKey: String) async throws -> [String] {
        guard let endpointString = provider.modelsEndpoint,
              let url = URL(string: endpointString) else {
            // Se o provedor não suporta a busca dinâmica ou não tem endpoint, retorna fallback vazio.
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        provider.applyAuthHeaders(to: &request, apiKey: apiKey)
        
        // Timeout curto para não prender a interface se a rede estiver ruim
        request.timeoutInterval = 15
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(APIModelListResponse.self, from: data)
        let modelIds = decodedResponse.data.map { $0.id }
        
        // Filtra possíveis sufixos vazios e ordena
        return modelIds.filter { !$0.isEmpty }.sorted()
    }
}
