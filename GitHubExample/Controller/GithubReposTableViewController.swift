// © 2019 Ralf Ebert — iOS Example Project: GitHubExample
// License: https://opensource.org/licenses/MIT

import Combine
import UIKit

class GithubReposTableViewController: UITableViewController, UISearchResultsUpdating {

    var items = [Item]()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.clearsSelectionOnViewWillAppear = true

        self.setupSearch()
        self.loadRepositories()
    }

    func loadRepositories() {

        let _ =
            self.$filterText
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .removeDuplicates()
            .tryMap { (searchText) -> URL in
                var urlComponents = URLComponents(string: "https://api.github.com/search/repositories")!
                urlComponents.queryItems = [
                    URLQueryItem(name: "q", value: "\(searchText ?? "")+language:swift"),
                    URLQueryItem(name: "sort", value: "stars"),
                    URLQueryItem(name: "order", value: "desc"),
                ]
                return urlComponents.url!
            }

            .flatMap { (url) -> AnyPublisher<[Item], Error> in
                let urlSession = URLSession.shared
                return
                    urlSession.dataTaskPublisher(for: url)
                    .map { $0.data }
                    .decode(type: RepositoryResult.self, decoder: JSONDecoder())
                    .map { $0.items }
                    .eraseToAnyPublisher()

            }
            .receive(on: RunLoop.main)
            .mapError { (error) -> Error in
                let alertController = UIAlertController(title: "Fehler", message: error.localizedDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: .default))
                self.present(alertController, animated: true, completion: nil)
                return error
            }
            .replaceError(with: [])
            .sink(
                receiveCompletion: { completion in
                    print(completion)
                },
                receiveValue: { result in
                    self.items = result
                    self.tableView.reloadData()
                }
            )

    }

    // MARK: - Suche

    private var searchController = UISearchController(searchResultsController: nil)

    func setupSearch() {
        // UISearchController registrieren
        self.navigationItem.searchController = self.searchController
        // Such-Bar immer sichtbar machen
        self.navigationItem.hidesSearchBarWhenScrolling = false
        // Ausgegraute Darstellung der Suchergebnisse deaktivieren
        self.searchController.obscuresBackgroundDuringPresentation = false
        // Aktualisierung der Suchergebnisse via UISearchResultsUpdating-Protokoll
        self.searchController.searchResultsUpdater = self
    }

    @Published var filterText: String = nil

    func updateSearchResults(for searchController: UISearchController) {
        self.filterText = searchController.searchBar.text
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CountryCell", for: indexPath)

        // Configure the cell...
        let item = self.items[indexPath.row]
        cell.textLabel?.text = item.name

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = self.items[indexPath.row]
        if let url = URL(string: item.htmlurl) {
            UIApplication.shared.open(url)
        }
    }

}
